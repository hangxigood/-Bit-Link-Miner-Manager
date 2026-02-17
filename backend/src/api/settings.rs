use flutter_rust_bridge::frb;
use crate::core::config::AppSettings;

#[frb(sync)]
pub fn get_app_settings() -> AppSettings {
    AppSettings::load()
}

#[frb(sync)]
pub fn save_app_settings(settings: AppSettings) -> Result<(), String> {
    settings.save()
}
