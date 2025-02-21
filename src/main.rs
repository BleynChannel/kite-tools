use std::ffi::OsStr;
use std::io::{self, BufReader, Result};
use std::process::{Command, Stdio};
use std::fs::File;
use std::io::BufRead;
use std::sync::mpsc::{channel, Receiver};
use std::thread;
use std::time::Duration;

use clap::{Parser, Subcommand};
use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    prelude::*,
    widgets::{Block, Borders, List, ListItem, Paragraph, ListState, Wrap, Clear},
};
use sysinfo::{Pid, System};

const OS_NAME: &str = "Arch Linux";

#[derive(Parser)]
#[command(name = "korshun-tools")]
#[command(about = "Система Коршун - Инструменты управления")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Установка системы
    Install,
    /// Восстановление системы
    Repair,
    /// Обновление системы
    Update,
    /// Очистка системы
    Uninstall,
    /// Установка дополнительных пакетов
    InstallPackage,
}

struct App {
    menu_state: ListState,
    menu_items: Vec<(&'static str, &'static str)>,
    status: String,
    error: Option<String>,
    show_error: bool,
    confirmation: Option<String>,
    confirmation_fn: Option<Box<dyn FnOnce(&mut Self)>>,
    show_confirmation: bool,
    package_list: Vec<String>,
    package_state: ListState,
    custom_package_input: String,
    view_state: ViewState,
    selected_packages: Vec<bool>,
    script_output: Vec<String>,
    script_receiver: Option<Receiver<CommandState>>,
    script_last_view_state: ViewState,
    script_process: Option<u32>,
    installation_type_state: ListState,
    installation_types: Vec<(&'static str, &'static str, &'static str)>,
    uninstall_type_state: ListState,
    uninstall_types: Vec<(&'static str, &'static str, &'static str)>,
}

#[derive(Clone, Copy)]
enum ViewState {
    MainMenu,
    PackageList,
    CustomPackageInput,
    ScriptProgress,
    InstallationType,
    UpdateCheck,
    UninstallType,
}

enum CommandState {
    OutputLine(String),
    Completed,
    Exit,
    StartError(std::io::Error),
    WaitError(std::io::Error),
}

impl App {
    fn new() -> Self {
        let menu_items = vec![
            ("Установка системы", "install"),
            ("Восстановление системы", "repair"),
            ("Обновление системы", "update"),
            ("Очистка системы", "uninstall"),
            ("Установка дополнительных пакетов", "install_package"),
        ];
        let mut state = ListState::default();
        state.select(Some(0));
        
        let installation_types = vec![
            (
                "Stable",
                "stable",
                "Стабильная сборка системы, рекомендуется для повседневного использования"
            ),
            (
                "Development",
                "developer",
                "Система с предустановленным инструментарием разработчика, \
                 включает дополнительные инструменты для разработки"
            ),
            (
                "Experimental",
                "experimental",
                "Экспериментальная версия с новейшими изменениями, \
                 может содержать нестабильные компоненты"
            ),
        ];

        let uninstall_types = vec![
            (
                "Очистка конфигураций",
                "config",
                "Удаление пользовательских настроек и конфигурационных файлов"
            ),
            (
                "Очистка программ",
                "apps",
                "Удаление установленных программ, сохраняя пользовательские данные"
            ),
            (
                "Полная очистка системы",
                "full",
                "Полное удаление системы, включая все данные и настройки"
            ),
        ];

        Self {
            menu_state: state,
            menu_items,
            status: "Добро пожаловать в инструменты управления Коршун".to_string(),
            error: None,
            show_error: false,
            confirmation: None,
            confirmation_fn: None,
            show_confirmation: false,
            package_list: Vec::new(),
            package_state: ListState::default(),
            custom_package_input: String::new(),
            view_state: ViewState::MainMenu,
            selected_packages: Vec::new(),
            script_output: Vec::new(),
            script_receiver: None,
            script_last_view_state: ViewState::MainMenu,
            script_process: None,
            installation_type_state: ListState::default(),
            installation_types,
            uninstall_type_state: ListState::default(),
            uninstall_types,
        }
    }

    fn next(&mut self) {
        let i = match self.menu_state.selected() {
            Some(i) => (i + 1) % self.menu_items.len(),
            None => 0,
        };
        self.menu_state.select(Some(i));
    }

    fn previous(&mut self) {
        let i = match self.menu_state.selected() {
            Some(i) => {
                if i == 0 {
                    self.menu_items.len() - 1
                } else {
                    i - 1
                }
            }
            None => 0,
        };
        self.menu_state.select(Some(i));
    }

    fn run_selected_action(&mut self) {
        match self.view_state {
            ViewState::MainMenu => {
                if let Some(selected) = self.menu_state.selected() {
                    match self.menu_items[selected].1 {
                        "install" => self.handle_install(),
                        "repair" => self.handle_repair(),
                        "update" => self.handle_update(),
                        "uninstall" => self.handle_uninstall(),
                        "install_package" => self.load_packages(),
                        _ => {}
                    }
                }
            }
            ViewState::PackageList => {
                self.install_selected_packages();
            }
            ViewState::CustomPackageInput => {
                self.install_custom_packages();
            }
            ViewState::ScriptProgress => {
                self.update_script_progress();
            }
            ViewState::InstallationType => {
                if !self.show_confirmation {
                    self.handle_installation_type();
                } else {
                    if let Some(selected) = self.installation_type_state.selected() {
                        let itype = self.installation_types[selected].1;
                        // let script_path = format!("{}/.local/share/bin/install.sh", home_path());
                        let script_path = "/usr/src/kite-tools/install.sh";
                        self.run_command_progress(script_path, vec![
                            itype.to_string(), 
                            "--no-confirm".to_string(), 
                            "--no-info".to_string()
                        ]);
                    }
                }
            }
            ViewState::UpdateCheck => {
                self.view_state = self.script_last_view_state;
                self.start_update();
            }
            ViewState::UninstallType => {
                if !self.show_confirmation {
                    self.handle_uninstall_type();
                }
            }
        }
    }
    
    fn run_command<I>(&mut self, program: I, args: Vec<String>) -> Receiver<CommandState>
    where
        I: AsRef<OsStr> + Send + 'static,
    {
        let (tx, rx) = channel();

        let process = Command::new(program)
            .args(args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn();

        match process {
            Ok(mut child) => {
                self.script_process = Some(child.id());

                // Получаем stdout и stderr
                if let Some(stdout) = child.stdout.take() {
                    let tx = tx.clone();
                    thread::spawn(move || {
                        let reader = BufReader::new(stdout);
                        for line in reader.lines() {
                            if let Ok(line) = line {
                                tx.send(CommandState::OutputLine(line)).unwrap_or_default();
                            }
                        }
                    });
                }

                if let Some(stderr) = child.stderr.take() {
                    let tx = tx.clone();
                    thread::spawn(move || {
                        let reader = BufReader::new(stderr);
                        for line in reader.lines() {
                            if let Ok(line) = line {
                                tx.send(CommandState::OutputLine(line)).unwrap_or_default();
                            }
                        }
                    });
                }

                // Ждем завершения процесса
                thread::spawn(move || {
                    match child.wait() {
                        Ok(status) => {
                            match status.success() {
                                true => tx.send(CommandState::Completed).unwrap_or_default(),
                                false => tx.send(CommandState::Exit).unwrap_or_default(),
                            }
                        }
                        Err(e) => {
                            tx.send(CommandState::WaitError(e)).unwrap_or_default();
                        }
                    }
                });
            }
            Err(e) => {
                tx.send(CommandState::StartError(e)).unwrap_or_default();
            }
        }

        rx
    }

    fn run_command_progress<I>(&mut self, program: I, args: Vec<String>)
    where
        I: AsRef<OsStr> + Send + 'static,
    {
        self.script_output.clear();
        self.script_last_view_state = self.view_state;
        self.view_state = ViewState::ScriptProgress;
        self.script_receiver = Some(self.run_command(program, args));
    }

    fn load_packages(&mut self) {
        // let package_list_path = format!("{}/.local/share/bin/custom_apps.lst", home_path());
        let package_list_path = "/usr/src/kite-tools/custom_apps.lst";
        
        self.package_list.clear();
        self.package_list.push("[ Установить свои пакеты ]".to_string());

        if let Ok(file) = File::open(&package_list_path) {
            let packages: Vec<String> = std::io::BufReader::new(file)
                .lines()
                .filter_map(Result::ok)
                .filter(|line| !line.trim().is_empty() && !line.starts_with('#'))
                .collect();
            self.package_list.extend(packages);
        }

        self.selected_packages = vec![false; self.package_list.len()];
        self.package_state.select(Some(0));
        self.view_state = ViewState::PackageList;
    }

    fn toggle_package(&mut self) {
        if let Some(selected) = self.package_state.selected() {
            if selected == 0 { // Установка пользовательских пакетов
                self.view_state = ViewState::CustomPackageInput;
            } else {
                self.selected_packages[selected] = !self.selected_packages[selected];
            }
        }
    }

    fn install_selected_packages(&mut self) {
        let selected_packages: Vec<String> = self.package_list.iter()
            .zip(self.selected_packages.iter())
            .skip(1)
            .filter(|(_, &selected)| selected)
            .map(|(package, _)| package.clone())
            .collect();

        if selected_packages.is_empty() {
            return;
        }

        let mut args: Vec<String> = vec!["-S".to_string(), "--noconfirm".to_string()];
        args.extend(selected_packages);

        self.run_command_progress("yay", args);
    }

    fn install_custom_packages(&mut self) {
        let packages: Vec<String> = self.custom_package_input
            .split_whitespace()
            .map(String::from)
            .collect();

        if packages.is_empty() {
            self.status = "Не указаны пакеты для установки".to_string();
            return;
        }

        let mut args: Vec<String> = vec!["-S".to_string(), "--noconfirm".to_string()];
        args.extend(packages);

        self.run_command_progress("yay", args);
        self.custom_package_input.clear();
    }

    fn start_package_installation(&mut self) {
        let selected_packages: Vec<String> = self.package_list.iter()
            .zip(self.selected_packages.iter())
            .skip(1)
            .filter(|(_, &selected)| selected)
            .map(|(package, _)| package.clone())
            .collect();

        if selected_packages.is_empty() {
            self.status = "Не выбраны пакеты для установки".to_string();
            return;
        }

        let mut args: Vec<String> = vec!["-S".to_string(), "--noconfirm".to_string()];
        args.extend(selected_packages);

        self.run_command_progress("yay", args);
    }

    fn update_script_progress(&mut self) {
        if let Some(ref rx) = self.script_receiver {
            let mut clear_process = false;
            
            while let Ok(state) = rx.try_recv() {
                match state {
                    CommandState::OutputLine(line) => self.script_output.push(line),
                    CommandState::Completed => {
                        clear_process = true;
                    }
                    CommandState::Exit => {
                        self.error = Some("Программа завершилась с ошибкой".to_string());
                        self.show_error = true;
                        clear_process = true;
                    }
                    CommandState::StartError(e) => {
                        self.error = Some(format!("Ошибка запуска: {}", e).to_string());
                        self.show_error = true;
                        clear_process = true;
                    }
                    CommandState::WaitError(e) => {
                        self.error = Some(format!("Ошибка выполнения: {}", e));
                        self.show_error = true;
                        clear_process = true;
                    }
                }
            }

            if clear_process {
                self.script_receiver = None;
                self.script_process = None;
            }
        }
    }

    fn set_confirmation<F>(&mut self, confirmation: String, confirmation_fn: F)
    where
        F: FnOnce(&mut Self) + 'static,
    {
        self.confirmation = Some(confirmation);
        self.confirmation_fn = Some(Box::new(confirmation_fn));
        self.show_confirmation = true;
    }

    fn hide_confirmation(&mut self) {
        self.show_confirmation = false;
        self.confirmation_fn = None;
        self.confirmation = None;
    }

    fn set_error(&mut self, error: String) {
        self.error = Some(error);
        self.show_error = true;
    }

    fn hide_error(&mut self) {
        self.show_error = false;
        self.error = None;
    }

    fn handle_install(&mut self) {
        self.view_state = ViewState::InstallationType;
        self.installation_type_state.select(Some(0));
    }

    fn handle_installation_type(&mut self) {
        if let Some(selected) = self.installation_type_state.selected() {
            let install_type = self.installation_types[selected].0;   
            let confirmation = format!(
                "Вы уверены, что хотите установить версию {}?\n\
                Все данные на диске будут удалены!",
                install_type
            );

            self.set_confirmation(confirmation, move |this| {
                this.run_selected_action();
            });
        }
    }

    fn handle_repair(&mut self) {
        match get_os_name() {
            Some(os_name) if os_name.contains(OS_NAME) => {
                let confirmation = "Вы действительно хотите восстановить систему?\n\
                                            Все пользовательские данные будут восстановлены до заводских настроек.".to_string();
                // let script_path = format!("{}/.local/share/bin/repair.sh", home_path());
                let script_path = "/usr/src/kite-tools/repair.sh";
                self.set_confirmation(confirmation, move |this| {
                    this.run_command_progress(script_path, vec![]);
                });
            }
            Some(os_name) => {
                self.set_error(format!(
                    "Восстановление не поддерживается для данной операционной системы: {}",
                    os_name
                ));
            }
            None => {
                self.set_error("Не удалось определить операционную систему".to_string());
            }
        }
    }

    fn handle_update(&mut self) {
        match get_os_name() {
            Some(os_name) if os_name.contains(OS_NAME) => {
                self.check_updates();
            }
            Some(os_name) => {
                self.set_error(format!(
                    "Обновление не поддерживается для данной операционной системы: {}",
                    os_name
                ));
            }
            None => {
                self.set_error("Не удалось определить операционную систему".to_string());
            }
        }
    }

    fn check_updates(&mut self) {
        self.script_output.clear();
        self.script_last_view_state = self.view_state;
        self.view_state = ViewState::UpdateCheck;
        
        // let script_path = format!("{}/.local/share/bin/check_update.sh", home_path());
        let script_path = "/usr/src/kite-tools/check_update.sh";
        let rx = self.run_command(script_path, vec!["--no-info".to_string()]);
        self.script_receiver = Some(rx);
    }

    fn start_update(&mut self) {
        // let script_path = format!("{}/.local/share/bin/update.sh", home_path());
        let script_path = "/usr/src/kite-tools/update.sh";
        self.run_command_progress(script_path, vec![]);
    }

    fn handle_uninstall(&mut self) {
        match get_os_name() {
            Some(os_name) if os_name.contains(OS_NAME) => {
                self.view_state = ViewState::UninstallType;
                self.uninstall_type_state.select(Some(0));
            }
            Some(os_name) => {
                self.set_error(format!(
                    "Обновление не поддерживается для данной операционной системы: {}",
                    os_name
                ));
            }
            None => {
                self.set_error("Не удалось определить операционную систему".to_string());
            }
        }
    }

    fn handle_uninstall_type(&mut self) {
        if let Some(selected) = self.uninstall_type_state.selected() {
            let uninstall_type = self.uninstall_types[selected];
            let confirmation = match uninstall_type.1 {
                "config" => "Вы уверены, что хотите удалить все пользовательские настройки?",
                "apps" => "Вы уверены, что хотите удалить все установленные программы?",
                "full" => "ВНИМАНИЕ! Вы уверены, что хотите полностью удалить систему?\n\
                          Все данные будут безвозвратно удалены!",
                _ => "Подтвердите удаление",
            };

            // let script_path = format!("{}/.local/share/bin/uninstall.sh", home_path());
            let script_path = "/usr/src/kite-tools/uninstall.sh";
            let uninstall_arg = uninstall_type.1.to_string();
            
            self.set_confirmation(confirmation.to_string(), move |this| {
                this.run_command_progress(script_path, vec![uninstall_arg]);
            });
        }
    }
}

fn home_path() -> String {
    std::env::var("HOME").unwrap_or_else(|_| ".".to_string())
}

// Функция для проверки OS
fn get_os_name() -> Option<String> {
    // if let Ok(output) = Command::new("cat")
    //     .arg("/etc/os-release")
    //     .output() {
    //     let content = String::from_utf8_lossy(&output.stdout);
    //     for line in content.lines() {
    //         if line.starts_with("NAME=") {
    //             return Some(line.trim_start_matches("NAME=")
    //                 .trim_matches('"')
    //                 .to_string());
    //         }
    //     }
    // }
    // None

    System::name()
}

fn get_os_version() -> Option<String> {
    // if let Ok(output) = Command::new("cat")
    //     .arg("/etc/os-release")
    //     .output() {
    //     let content = String::from_utf8_lossy(&output.stdout);
    //     for line in content.lines() {
    //         if line.starts_with("VERSION=") {
    //             return Some(line.trim_start_matches("VERSION=")
    //                 .trim_matches('"')
    //                 .to_string());
    //         }
    //     }
    // }
    // None

    System::os_version()
}

fn run_tui() -> Result<()> {
    enable_raw_mode()?;
    execute!(io::stdout(), EnterAlternateScreen)?;
    
    let mut terminal = Terminal::new(CrosstermBackend::new(io::stdout()))?;
    let mut app = App::new();
    let mut should_quit = false;

    while !should_quit {
        // Обновляем прогресс скрипта
        app.update_script_progress();

        terminal.draw(|frame| {
            match app.view_state {
                ViewState::MainMenu => {
                    let chunks = Layout::default()
                        .direction(Direction::Vertical)
                        .constraints([
                            Constraint::Length(3),
                            Constraint::Min(10),
                            Constraint::Length(3),
                            Constraint::Length(3),
                        ])
                        .split(frame.area());

                    // Заголовок
                    let title = Paragraph::new("Система Коршун - Инструменты управления")
                        .block(Block::default().borders(Borders::ALL))
                        .alignment(Alignment::Center);
                    frame.render_widget(title, chunks[0]);

                    // Меню
                    let menu_items: Vec<ListItem> = app.menu_items
                        .iter()
                        .map(|(name, _)| ListItem::new(*name))
                        .collect();

                    let menu = List::new(menu_items)
                        .block(Block::default().borders(Borders::ALL).title("Меню"))
                        .highlight_style(Style::default().bg(Color::DarkGray))
                        .highlight_symbol(">> ");

                    frame.render_stateful_widget(menu, chunks[1], &mut app.menu_state);

                    // Статус
                    let status = Paragraph::new(app.status.clone())
                        .block(Block::default().borders(Borders::ALL).title("Статус"))
                        .wrap(Wrap { trim: true });
                    frame.render_widget(status, chunks[2]);

                    if !app.show_confirmation {
                        build_hints(frame, chunks, "↑/↓: Навигация | Enter: Выбрать | q: Выход");
                    }
                }
                ViewState::PackageList => {
                    let chunks = Layout::default()
                        .direction(Direction::Vertical)
                        .constraints([
                            Constraint::Length(3),
                            Constraint::Min(10),
                            Constraint::Length(3),
                        ])
                        .split(frame.area());

                    let title = Paragraph::new("Выбор пакетов для установки")
                        .block(Block::default().borders(Borders::ALL))
                        .alignment(Alignment::Center);
                    frame.render_widget(title, chunks[0]);

                    let packages: Vec<ListItem> = app.package_list
                        .iter()
                        .enumerate()
                        .map(|(i, package)| {
                            if i == 0 { // Для пункта "Установить свои пакеты"
                                ListItem::new(package.as_str())
                            } else {
                                let prefix = if app.selected_packages[i] { "[X] " } else { "[ ] " };
                                ListItem::new(format!("{}{}", prefix, package))
                            }
                        })
                        .collect();

                    let packages_list = List::new(packages)
                        .block(Block::default().borders(Borders::ALL).title("Доступные пакеты"))
                        .highlight_style(Style::default().bg(Color::DarkGray))
                        .highlight_symbol(">> ");

                    frame.render_stateful_widget(packages_list, chunks[1], &mut app.package_state);

                    build_hints(frame, chunks, "↑/↓: Навигация | Пробел: Выбрать | Enter: Подтвердить установку | Esc: Назад | q: Выход");
                }
                ViewState::CustomPackageInput => {
                    let chunks = Layout::default()
                        .direction(Direction::Vertical)
                        .constraints([
                            Constraint::Length(3),
                            Constraint::Min(3),
                            Constraint::Length(3),
                        ])
                        .split(frame.area());

                    let title = Paragraph::new("Введите названия пакетов через пробел")
                        .block(Block::default().borders(Borders::ALL))
                        .alignment(Alignment::Center);
                    frame.render_widget(title, chunks[0]);

                    let input = Paragraph::new(app.custom_package_input.as_str())
                        .block(Block::default().borders(Borders::ALL).title("Ввод пакетов"));
                    frame.render_widget(input, chunks[1]);

                    build_hints(frame, chunks, "Enter: Установить | Esc: Назад | q: Выход");
                }
                ViewState::ScriptProgress => {
                    let chunks = Layout::default()
                        .direction(Direction::Vertical)
                        .constraints([
                            Constraint::Length(3),
                            Constraint::Min(10),
                            Constraint::Length(3),
                        ])
                        .split(frame.area());

                    let title = Paragraph::new("Установка пакетов")
                        .block(Block::default().borders(Borders::ALL))
                        .alignment(Alignment::Center);
                    frame.render_widget(title, chunks[0]);

                    let output_text = app.script_output
                        .iter()
                        .rev() // Показываем последние строки
                        .take(frame.area().height as usize - 8)
                        .rev()
                        .cloned()
                        .collect::<Vec<String>>()
                        .join("\n");

                    let output = Paragraph::new(output_text)
                        .block(Block::default().borders(Borders::ALL).title("Вывод"))
                        .wrap(Wrap { trim: true });
                    frame.render_widget(output, chunks[1]);

                    let hints = match app.script_process {
                        Some(_) => "Выполняется программа... | Esc: Отмена",
                        None => "Программа завершена | Enter: Закрыть | Esc: Вернуться",
                    };

                    build_hints(frame, chunks, hints);
                }
                ViewState::InstallationType => {
                    let chunks = Layout::default()
                        .direction(Direction::Vertical)
                        .constraints([
                            Constraint::Length(3),
                            Constraint::Min(10),
                            Constraint::Length(5),
                            Constraint::Length(3),
                        ])
                        .split(frame.area());

                    let title = Paragraph::new("Выбор типа установки")
                        .block(Block::default().borders(Borders::ALL))
                        .alignment(Alignment::Center);
                    frame.render_widget(title, chunks[0]);

                    let items: Vec<ListItem> = app.installation_types
                        .iter()
                        .map(|(name, _, desc)| {
                            ListItem::new(vec![
                                Line::from(*name),
                                Line::from(format!("  {}", textwrap::fill(*desc, 60))),
                            ])
                        })
                        .collect();

                    let installations = List::new(items)
                        .block(Block::default().borders(Borders::ALL).title("Доступные варианты"))
                        .highlight_style(Style::default().bg(Color::DarkGray))
                        .highlight_symbol(">> ");

                    frame.render_stateful_widget(installations, chunks[1], &mut app.installation_type_state);

                    if !app.show_confirmation {
                        build_hints(frame, chunks, "↑/↓: Навигация | Enter: Выбрать | Esc: Назад | q: Выход");
                    }
                }
                ViewState::UpdateCheck => {
                    let area = centered_rect(70, 40, frame.area());
                    
                    let chunks = Layout::default()
                        .direction(Direction::Vertical)
                        .constraints([
                            Constraint::Length(3),
                            Constraint::Min(10),
                            Constraint::Length(3),
                        ])
                        .split(area);

                    // Очищаем область под окном
                    frame.render_widget(Clear, area);

                    let title = Paragraph::new("Проверка обновлений")
                        .block(Block::default().borders(Borders::ALL))
                        .alignment(Alignment::Center);
                    frame.render_widget(title, chunks[0]);

                    let output_text = app.script_output
                        .iter()
                        .rev()
                        .take((area.height as usize).saturating_sub(8))
                        .rev()
                        .cloned()
                        .collect::<Vec<String>>()
                        .join("\n");

                    let output = Paragraph::new(output_text)
                        .block(Block::default().borders(Borders::ALL).title("Доступные обновления"))
                        .wrap(Wrap { trim: true });
                    frame.render_widget(output, chunks[1]);

                    let hints = "Проверка обновлений... | Esc: Отмена";

                    build_hints(frame, chunks, hints);


                    if app.script_receiver.is_none() {
                        if !app.show_error {
                            let version = app.script_output.iter()
                                .map(|v| v.trim())
                                .collect::<String>();

                            let current_version = get_os_version()
                                .unwrap_or("0.0.0".to_string());

                            if !version.is_empty() && current_version != version {
                                let confirmation = format!("Найдена новая версия {}!\n\
                                    Вы действительно хотите обновить систему?", version);
                                app.set_confirmation(confirmation, move |this| {
                                    this.view_state = ViewState::UpdateCheck;
                                    this.run_selected_action();
                                });
                            } else {
                                let confirmation = "Версия системы актуальна".to_string();
                                app.set_confirmation(confirmation, move |this| {
                                    this.view_state = ViewState::MainMenu;
                                });
                            }
                        }

                        app.view_state = app.script_last_view_state;
                    }
                }
                ViewState::UninstallType => {
                    let chunks = Layout::default()
                        .direction(Direction::Vertical)
                        .constraints([
                            Constraint::Length(3),
                            Constraint::Min(10),
                            Constraint::Length(5),
                            Constraint::Length(3),
                        ])
                        .split(frame.area());

                    let title = Paragraph::new("Выбор типа очистки")
                        .block(Block::default().borders(Borders::ALL))
                        .alignment(Alignment::Center);
                    frame.render_widget(title, chunks[0]);

                    let items: Vec<ListItem> = app.uninstall_types
                        .iter()
                        .map(|(name, _, desc)| {
                            ListItem::new(vec![
                                Line::from(*name),
                                Line::from(format!("  {}", textwrap::fill(*desc, 60))),
                            ])
                        })
                        .collect();

                    let uninstall_list = List::new(items)
                        .block(Block::default().borders(Borders::ALL).title("Доступные варианты"))
                        .highlight_style(Style::default().bg(Color::DarkGray))
                        .highlight_symbol(">> ");

                    frame.render_stateful_widget(uninstall_list, chunks[1], &mut app.uninstall_type_state);

                    if !app.show_confirmation {
                        build_hints(frame, chunks, "↑/↓: Навигация | Enter: Выбрать | Esc: Назад | q: Выход");
                    }
                }
            }

            // Подтверждение (если есть)
            if app.show_confirmation {
                if let Some(confirmation) = &app.confirmation {
                    let confirmation_text = format!("{}\n\nEnter - Подтвердить\nEsc - Отменить", confirmation);
                    let confirmation_block = Paragraph::new(confirmation_text)
                    .block(Block::default().borders(Borders::ALL).title("Подтверждение"))
                    .alignment(Alignment::Center)
                    .wrap(Wrap { trim: true });
    
                    let confirmation_area = centered_rect(60, 20, frame.area());
                    frame.render_widget(Clear, confirmation_area); // Очищаем область под сообщением
                    frame.render_widget(confirmation_block, confirmation_area);
                }
            }

            // Ошибка (если есть)
            if app.show_error {
                if let Some(error) = &app.error {
                    let error_text = format!("{}\n\nНажмите Enter для продолжения", error);
                    let error_block = Paragraph::new(error_text)
                        .block(Block::default().borders(Borders::ALL).title("Ошибка"))
                        .style(Style::default().fg(Color::Red))
                        .wrap(Wrap { trim: true });
                    
                    let error_area = centered_rect(60, 20, frame.area());
                    frame.render_widget(Clear, error_area); // Очищаем область под сообщением
                    frame.render_widget(error_block, error_area);
                }
            }
        })?;

        // Добавляем неблокирующее чтение событий
        if crossterm::event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if app.show_error {
                    match key.code {
                        KeyCode::Enter | KeyCode::Esc => app.hide_error(),
                        _ => {}
                    }
                } else if app.show_confirmation {
                    match key.code {
                        KeyCode::Enter => {
                            if let Some(confirmation_fn) = app.confirmation_fn.take() {
                                confirmation_fn(&mut app);
                            }
                            app.hide_confirmation();
                        },
                        KeyCode::Esc => app.hide_confirmation(),
                        _ => {}
                    }
                } else {
                    match app.view_state {
                        ViewState::MainMenu => {
                            match key.code {
                                KeyCode::Char('q') => should_quit = true,
                                KeyCode::Up => app.previous(),
                                KeyCode::Down => app.next(),
                                KeyCode::Enter => app.run_selected_action(),
                                _ => {}
                            }
                        }
                        ViewState::PackageList => {
                            match key.code {
                                KeyCode::Char('q') => should_quit = true,
                                KeyCode::Up => {
                                    let i = match app.package_state.selected() {
                                        Some(i) => {
                                            if i == 0 {
                                                app.package_list.len() - 1
                                            } else {
                                                i - 1
                                            }
                                        }
                                        None => 0,
                                    };
                                    app.package_state.select(Some(i));
                                }
                                KeyCode::Down => {
                                    let i = match app.package_state.selected() {
                                        Some(i) => (i + 1) % app.package_list.len(),
                                        None => 0,
                                    };
                                    app.package_state.select(Some(i));
                                }
                                KeyCode::Char(' ') => app.toggle_package(),
                                KeyCode::Enter => {
                                    if app.selected_packages.iter().any(|&selected| selected) {
                                        app.start_package_installation();
                                    } else {
                                        app.toggle_package();
                                    }
                                }
                                KeyCode::Esc => app.view_state = ViewState::MainMenu,
                                _ => {}
                            }
                        }
                        ViewState::CustomPackageInput => {
                            match key.code {
                                KeyCode::Char('q') => should_quit = true,
                                KeyCode::Char(c) => app.custom_package_input.push(c),
                                KeyCode::Backspace => { app.custom_package_input.pop(); }
                                KeyCode::Enter => app.run_selected_action(),
                                KeyCode::Esc => app.view_state = ViewState::PackageList,
                                _ => {}
                            }
                        }
                        ViewState::ScriptProgress => {
                            match key.code {
                                KeyCode::Enter => {
                                    if app.script_process.is_none() {
                                        app.view_state = app.script_last_view_state;
                                    }
                                }
                                KeyCode::Esc => {
                                    if let Some(pid) = app.script_process.take() {
                                        let system = System::new_all();
                                        if let Some(process) = system.process(Pid::from_u32(pid)) {
                                            process.kill();
                                        }

                                        app.status = "Задача отменена".to_string();
                                    }
                                    app.view_state = app.script_last_view_state;
                                }
                                _ => {}
                            }
                        }
                        ViewState::InstallationType => {
                            match key.code {
                                KeyCode::Char('q') => should_quit = true,
                                KeyCode::Up => {
                                    let i = match app.installation_type_state.selected() {
                                        Some(i) => {
                                            if i == 0 {
                                                app.installation_types.len() - 1
                                            } else {
                                                i - 1
                                            }
                                        }
                                        None => 0,
                                    };
                                    app.installation_type_state.select(Some(i));
                                }
                                KeyCode::Down => {
                                    let i = match app.installation_type_state.selected() {
                                        Some(i) => (i + 1) % app.installation_types.len(),
                                        None => 0,
                                    };
                                    app.installation_type_state.select(Some(i));
                                }
                                KeyCode::Enter => app.run_selected_action(),
                                KeyCode::Esc => app.view_state = ViewState::MainMenu,
                                _ => {}
                            }
                        }
                        ViewState::UpdateCheck => {
                            match key.code {
                                KeyCode::Esc => {
                                    if let Some(pid) = app.script_process.take() {
                                        let system = System::new_all();
                                        if let Some(process) = system.process(Pid::from_u32(pid)) {
                                            process.kill();
                                        }

                                        app.status = "Задача отменена".to_string();
                                    }
                                    app.view_state = ViewState::MainMenu;
                                }
                                _ => {}
                            }
                        }
                        ViewState::UninstallType => {
                            match key.code {
                                KeyCode::Char('q') => should_quit = true,
                                KeyCode::Up => {
                                    let i = match app.uninstall_type_state.selected() {
                                        Some(i) => {
                                            if i == 0 {
                                                app.uninstall_types.len() - 1
                                            } else {
                                                i - 1
                                            }
                                        }
                                        None => 0,
                                    };
                                    app.uninstall_type_state.select(Some(i));
                                }
                                KeyCode::Down => {
                                    let i = match app.uninstall_type_state.selected() {
                                        Some(i) => (i + 1) % app.uninstall_types.len(),
                                        None => 0,
                                    };
                                    app.uninstall_type_state.select(Some(i));
                                }
                                KeyCode::Enter => app.run_selected_action(),
                                KeyCode::Esc => app.view_state = ViewState::MainMenu,
                                _ => {}
                            }
                        }
                    }
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(io::stdout(), LeaveAlternateScreen)?;
    Ok(())
}

fn build_hints<S>(frame: &mut Frame<'_>, chunks: std::rc::Rc<[Rect]>, text: S)
where
    S: AsRef<str>,
{
    // Подсказки
    let hints = Paragraph::new(text.as_ref())
        .block(Block::default().borders(Borders::ALL))
        .alignment(Alignment::Center);
    frame.render_widget(hints, chunks[chunks.len() - 1]);
}

// Вспомогательная функция для центрирования блока
fn centered_rect(percent_x: u16, percent_y: u16, r: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}


fn main() -> Result<()> {
    //TODO: Исправить блокировку вывода в близжайшем будующем
    // let cli = Cli::parse();

    // match &cli.command {
    //     Some(Commands::Install) => {
    //         let mut app = App::new();
    //         app.run_script("install", None::<std::iter::Empty<&str>>);
    //         println!("{}", app.status);
    //         if let Some(error) = app.error {
    //             eprintln!("Ошибка: {}", error);
    //         }
    //     }
    //     Some(Commands::Repair) => {
    //         let mut app = App::new();
    //         app.run_script("repair", None::<std::iter::Empty<&str>>);
    //         println!("{}", app.status);
    //         if let Some(error) = app.error {
    //             eprintln!("Ошибка: {}", error);
    //         }
    //     }
    //     Some(Commands::Update) => {
    //         let mut app = App::new();
    //         app.run_script("update", None::<std::iter::Empty<&str>>);
    //         println!("{}", app.status);
    //         if let Some(error) = app.error {
    //             eprintln!("Ошибка: {}", error);
    //         }
    //     }
    //     Some(Commands::Uninstall) => {
    //         let mut app = App::new();
    //         app.run_script("uninstall", None::<std::iter::Empty<&str>>);
    //         println!("{}", app.status);
    //         if let Some(error) = app.error {
    //             eprintln!("Ошибка: {}", error);
    //         }
    //     }
    //     Some(Commands::InstallPackage) => {
    //         let mut app = App::new();
    //         app.load_packages();
    //         println!("{}", app.status);
    //         if let Some(error) = app.error {
    //             eprintln!("Ошибка: {}", error);
    //         }
    //     }
    //     None => {
    //         run_tui()?;
    //     }
    // }

    // Ok(())

    run_tui()
}