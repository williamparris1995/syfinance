mod application;
mod domain;
mod infrastructure;
mod presentation;

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
