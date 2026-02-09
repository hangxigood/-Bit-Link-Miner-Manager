use flutter_rust_bridge::frb;

#[frb(sync)] // Synchronous return
pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
