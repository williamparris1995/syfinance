mod application;
mod domain;
mod infrastructure;
mod presentation;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        .setup(|_app| {
            // NotificationService::reschedule_all() should be called here once the app state is wired.
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
