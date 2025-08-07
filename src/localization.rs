use std::collections::HashMap;

#[derive(PartialEq, Clone, Copy)]
pub enum Language {
    Russian,
    English,
}

pub struct Localization {
    strings: HashMap<&'static str, [&'static str; 2]>, // [Russian, English]
}

impl Localization {
    pub fn new() -> Self {
        let mut strings = HashMap::new();
        
        // General
        strings.insert("app_title", ["Система Коршун - Инструменты управления", "Kite Linux - Management Tools"]);
        strings.insert("menu", ["Меню", "Menu"]);
        strings.insert("status", ["Статус", "Status"]);
        strings.insert("package_list_title", ["Выбор пакетов для установки", "Select packages to install"]);
        strings.insert("available_packages", ["Доступные пакеты", "Available packages"]);

        // Menu items
        strings.insert("menu_install", ["Установка системы", "System Installation"]);
        strings.insert("menu_update", ["Обновление системы", "System Update"]);
        strings.insert("menu_uninstall", ["Очистка системы", "System Uninstall"]);
        strings.insert("menu_install_package", ["Установка пакетов", "Install Packages"]);

        // Menu status
        strings.insert("welcome_menu_status", ["Добро пожаловать в инструменты управления Коршун", "Welcome to Kite Tools"]);

        // Installation types
        strings.insert("select_installation_type", ["Выбор типа установки", "Select installation type"]);
        strings.insert("available_installation_types", ["Доступные варианты", "Available options"]);
        strings.insert("installation_types_stable", ["Стабильная сборка", "Stable"]);
        strings.insert("installation_types_developer", ["Сборка разработчика", "Developer"]);
        strings.insert("installation_types_experimental", ["Экспериментальная сборка", "Experimental"]);

        strings.insert("installation_types_description_stable", [
            "Стабильная сборка системы, рекомендуется для повседневного использования", 
            "Stable"]);
        strings.insert("installation_types_description_developer", [
            "Система с предустановленным инструментарием разработчика, \
            включает дополнительные инструменты для разработки", 
            "Developer"]);
        strings.insert("installation_types_description_experimental", [
            "Экспериментальная версия с новейшими изменениями, \
            может содержать нестабильные компоненты", 
            "Experimental"]);

        // Uninstall types
        strings.insert("select_uninstall_type", ["Выбор типа очистки", "Select uninstall type"]);
        strings.insert("uninstall_types_config", ["Очистка конфигураций", "Clear Configurations"]);
        strings.insert("uninstall_types_apps", ["Очистка программ", "Clear Applications"]);
        strings.insert("uninstall_types_full", ["Полная очистка системы", "Full System Clear"]);

        strings.insert("uninstall_types_description_config", [
            "Удаление пользовательских настроек и конфигурационных файлов", 
            "Clear Configurations"]);
        strings.insert("uninstall_types_description_apps", [
            "Удаление установленных программ, сохраняя пользовательские данные", 
            "Clear Applications"]);
        strings.insert("uninstall_types_description_full", [
            "Полное удаление системы, включая все данные и настройки", 
            "Full System Clear"]);

        // Update check
        strings.insert("update_check_title", ["Проверка обновлений", "Update Check"]);
        strings.insert("available_updates", ["Доступные обновления", "Available Updates"]);

        // Script progress
        strings.insert("script_progress_title", ["Установка пакетов", "Package Installation"]);
        strings.insert("script_output", ["Вывод", "Output"]);

        // Instructions
        strings.insert("instructions_custom_package_input", [
            "Введите названия пакетов через пробел", 
            "Enter package names separated by spaces"]);

        // Warning messages
        strings.insert("warning_installation", [
            "Вы уверены, что хотите установить версию {}?\n\
            Все данные на диске будут удалены!", 
            "Are you sure you want to install version {}?\n\
            All data on the disk will be deleted!"]);
        strings.insert("warning_uninstall_config", [
            "Вы уверены, что хотите удалить все пользовательские настройки?", 
            "Are you sure you want to uninstall all user configurations?"]);
        strings.insert("warning_uninstall_apps", [
            "Вы уверены, что хотите удалить все установленные программы?", 
            "Are you sure you want to uninstall all installed applications?"]);
        strings.insert("warning_uninstall_full", [
            "ВНИМАНИЕ! Вы уверены, что хотите полностью удалить систему?\n\
            Все данные будут безвозвратно удалены!", 
            "Are you sure you want to uninstall the entire system?\n\
            All data will be permanently deleted!"]);
        strings.insert("confirm_uninstall", ["Подтвердите удаление", "Confirm uninstall"]);
        strings.insert("warning_update_found", [
            "Найдена новая версия {}!\n\
            Вы действительно хотите обновить систему?", 
            "New version {} found!\n\
            Are you sure you want to update the system?"]);
        strings.insert("version_up_to_date", [
            "Версия системы актуальна", 
            "System version is up to date"]);
        
        // Error handling
        strings.insert("command_success", ["Программа завершилась успешно", "Command completed successfully"]);
        strings.insert("command_error", ["Программа завершилась с ошибкой", "Command failed"]);
        strings.insert("command_error_start", ["Ошибка запуска: {}", "Command failed: {}"]);
        strings.insert("command_error_process", ["Ошибка выполнения: {}", "Command failed: {}"]);
        strings.insert("system_already_installed", ["Система уже установлена", "System already installed"]);
        strings.insert("system_not_detected", ["Не удалось определить операционную систему", "System not detected"]);
        strings.insert("update_not_supported", ["Обновление не поддерживается для данной операционной системы: {}", "Update not supported for this operating system: {}"]);
        strings.insert("package_error_status", ["Не указаны пакеты для установки", "No packages specified for installation"]);

        // Custom packages
        strings.insert("custom_packages", ["[ Установить свои пакеты ]", "[ Install Custom Packages ]"]);

        // Navigation
        strings.insert("main_menu_navigation_hints", [
            "↑/↓: Навигация | Enter: Выбрать | q: Выход | F2: Переключение языка", 
            "↑/↓: Navigation | Enter: Select | q: Exit | F2: Language Switch"]);
        strings.insert("package_list_navigation_hints", [
            "↑/↓: Навигация | Пробел: Выбрать | Enter: Подтвердить установку | Esc: Назад | q: Выход", 
            "↑/↓: Navigation | Space: Select | Enter: Confirm Installation | Esc: Back | q: Exit"]);
        strings.insert("custom_package_input_navigation_hints", [
            "Enter: Установить | Esc: Назад", 
            "Enter: Install | Esc: Back"]);
        strings.insert("script_running_hints", [
            "Выполняется программа... | Esc: Отмена", 
            "Script is running... | Esc: Cancel"]);
        strings.insert("script_finished_hints", [
            "Программа завершена | Enter: Закрыть | Esc: Вернуться", 
            "Script finished | Enter: Close | Esc: Back"]);
        strings.insert("installation_type_navigation_hints", [
            "↑/↓: Навигация | Enter: Выбрать | q: Выход", 
            "↑/↓: Navigation | Enter: Select | q: Exit"]);
        strings.insert("update_check_hints", [
            "Проверка обновлений... | Esc: Отмена", 
            "Update check... | Esc: Cancel"]);
        strings.insert("uninstall_type_navigation_hints", [
            "↑/↓: Навигация | Enter: Выбрать | q: Выход", 
            "↑/↓: Navigation | Enter: Select | q: Exit"]);
        strings.insert("uninstall_confirmation", [
            "{}\n\nEnter - Подтвердить\nEsc - Отменить", 
            "{}\n\nEnter - Confirm\nEsc - Cancel"]);
        strings.insert("uninstall_error_message", [
            "{}\n\nНажмите Enter для продолжения", 
            "{}\n\nPress Enter to continue"]);
        strings.insert("uninstall_info_message", [
            "{}\n\nНажмите Enter для продолжения", 
            "{}\n\nPress Enter to continue"]);

        // Other
        strings.insert("package_input_title", ["Ввод пакетов", "Package Input"]);
        strings.insert("confirmation", ["Подтверждение", "Confirmation"]);
        strings.insert("error", ["Ошибка", "Error"]);
        strings.insert("info", ["Информация", "Info"]);
        strings.insert("task_cancelled", ["Задача отменена", "Task Cancelled"]);

        Self { strings }
    }
    
    pub fn get(&self, key: &str, lang: Language) -> String {
        self.strings.get(key)
            .and_then(|translations| translations.get(lang as usize).copied().map(|x| x.to_string()))
            .unwrap_or(key.to_string())
    }
    
    pub fn get_fmt(&self, key: &str, lang: Language, arg: &str) -> String {
        self.get(key, lang).replace("{}", arg)
    }
}

lazy_static::lazy_static! {
    pub static ref L10N: Localization = Localization::new();
}
