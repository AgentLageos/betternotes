//! Basic information about the native library, used to check that Dart and Rust are wired up.

/// Version of the `bn_renderer` crate, e.g. "0.1.0".
#[flutter_rust_bridge::frb(sync)]
pub fn renderer_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Called once by `RustLib.init()` before any other call.
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Forwards Rust panics and logs to Dart.
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_set() {
        assert!(!renderer_version().is_empty());
    }
}
