//! DevTools integration test
//!
//! Starts a minimal Tauri app with devtools plugin enabled,
//! then verifies the gRPC server is accessible.
//!
//! Run: cargo test --manifest-path src-tauri/Cargo.toml --features devtools --test devtools_integration -- --nocapture --test-threads=1

#[cfg(feature = "devtools")]
mod devtools_tests {
    use std::net::TcpStream;
    use std::time::Duration;
    use tauri::Manager;

    /// Verify that devtools gRPC server starts and is accessible.
    ///
    /// NOTE: This test must run single-threaded (--test-threads=1) because
    /// the devtools plugin initializes a global tracing subscriber.
    #[tokio::test]
    async fn test_devtools_server_listens() {
        // Create a minimal Tauri app with devtools plugin
        let app = tauri::test::mock_builder()
            .plugin(tauri_plugin_devtools::init())
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .expect("failed to build mock app with devtools");

        let handle = app.handle();

        // Get the Devtools managed state which contains connection info
        let devtools = handle.state::<tauri_plugin_devtools::Devtools>();
        let port = devtools.connection.port;
        let host = devtools.connection.host;

        println!("DevTools server listening on {}:{}", host, port);

        // Verify port is in valid range
        assert!(port > 0, "DevTools port should be assigned");
        assert!(port >= 1024, "DevTools port should be >= 1024");

        // Give the server thread a moment to start
        tokio::time::sleep(Duration::from_millis(500)).await;

        // Verify the port is actually listening (gRPC server should be up)
        let addr = format!("{}:{}", host, port);
        let stream = TcpStream::connect_timeout(
            &addr.parse().unwrap(),
            Duration::from_secs(3),
        );
        assert!(
            stream.is_ok(),
            "DevTools gRPC server should be listening on {} (error: {:?})",
            addr,
            stream.err()
        );

        println!("✅ DevTools gRPC server is listening on port {}", port);
    }
}

// When devtools feature is not enabled, this test file is empty
#[cfg(not(feature = "devtools"))]
mod no_devtools {
    #[test]
    fn test_devtools_feature_disabled() {
        println!("DevTools feature not enabled - skipping integration tests");
    }
}
