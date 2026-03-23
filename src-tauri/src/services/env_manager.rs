use super::env_checker::EnvConflict;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[cfg(target_os = "windows")]
use winreg::enums::*;
#[cfg(target_os = "windows")]
use winreg::RegKey;

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BackupInfo {
    pub backup_path: String,
    pub timestamp: String,
    pub conflicts: Vec<EnvConflict>,
}

/// Delete environment variables with automatic backup
pub fn delete_env_vars(conflicts: Vec<EnvConflict>) -> Result<BackupInfo, String> {
    // Step 1: Create backup
    let backup_info = create_backup(&conflicts)?;

    // Step 2: Delete variables
    for conflict in &conflicts {
        match delete_single_env(conflict) {
            Ok(_) => {}
            Err(e) => {
                // If deletion fails, we keep the backup but return error
                return Err(format!(
                    "删除环境变量失败: {}. 备份已保存到: {}",
                    e, backup_info.backup_path
                ));
            }
        }
    }

    Ok(backup_info)
}

/// Create backup file before deletion
fn create_backup(conflicts: &[EnvConflict]) -> Result<BackupInfo, String> {
    // Get backup directory
    let backup_dir = get_backup_dir()?;
    fs::create_dir_all(&backup_dir).map_err(|e| format!("创建备份目录失败: {e}"))?;

    // Generate backup file name with timestamp
    let timestamp = Utc::now().format("%Y%m%d_%H%M%S").to_string();
    let backup_file = backup_dir.join(format!("env-backup-{timestamp}.json"));

    // Create backup data
    let backup_info = BackupInfo {
        backup_path: backup_file.to_string_lossy().to_string(),
        timestamp: timestamp.clone(),
        conflicts: conflicts.to_vec(),
    };

    // Write backup file
    let json = serde_json::to_string_pretty(&backup_info)
        .map_err(|e| format!("序列化备份数据失败: {e}"))?;

    fs::write(&backup_file, json).map_err(|e| format!("写入备份文件失败: {e}"))?;

    Ok(backup_info)
}

/// Get backup directory path
fn get_backup_dir() -> Result<PathBuf, String> {
    let home = dirs::home_dir().ok_or("无法获取用户主目录")?;
    Ok(home.join(".haipee").join("backups"))
}

/// Delete a single environment variable
#[cfg(target_os = "windows")]
fn delete_single_env(conflict: &EnvConflict) -> Result<(), String> {
    match conflict.source_type.as_str() {
        "system" => {
            if conflict.source_path.contains("HKEY_CURRENT_USER") {
                let hkcu = RegKey::predef(HKEY_CURRENT_USER)
                    .open_subkey_with_flags("Environment", KEY_ALL_ACCESS)
                    .map_err(|e| format!("打开注册表失败: {}", e))?;

                hkcu.delete_value(&conflict.var_name)
                    .map_err(|e| format!("删除注册表项失败: {}", e))?;
            } else if conflict.source_path.contains("HKEY_LOCAL_MACHINE") {
                let hklm = RegKey::predef(HKEY_LOCAL_MACHINE)
                    .open_subkey_with_flags(
                        "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment",
                        KEY_ALL_ACCESS,
                    )
                    .map_err(|e| format!("打开系统注册表失败 (需要管理员权限): {}", e))?;

                hklm.delete_value(&conflict.var_name)
                    .map_err(|e| format!("删除系统注册表项失败: {}", e))?;
            }
            Ok(())
        }
        "file" => Err("Windows 系统不应该有文件类型的环境变量".to_string()),
        _ => Err(format!("未知的环境变量来源类型: {}", conflict.source_type)),
    }
}

#[cfg(not(target_os = "windows"))]
fn delete_single_env(conflict: &EnvConflict) -> Result<(), String> {
    match conflict.source_type.as_str() {
        "file" => {
            // Parse file path and line number from source_path (format: "path:line")
            let parts: Vec<&str> = conflict.source_path.split(':').collect();
            if parts.len() < 2 {
                return Err("无效的文件路径格式".to_string());
            }

            let file_path = parts[0];

            // Read file content
            let content = fs::read_to_string(file_path)
                .map_err(|e| format!("读取文件失败 {file_path}: {e}"))?;

            // Filter out the line containing the environment variable
            let new_content: Vec<String> = content
                .lines()
                .filter(|line| {
                    let trimmed = line.trim();
                    let export_line = trimmed.strip_prefix("export ").unwrap_or(trimmed);

                    // Check if this line sets the target variable
                    if let Some(eq_pos) = export_line.find('=') {
                        let var_name = export_line[..eq_pos].trim();
                        var_name != conflict.var_name
                    } else {
                        true
                    }
                })
                .map(|s| s.to_string())
                .collect();

            // Write back to file
            fs::write(file_path, new_content.join("\n"))
                .map_err(|e| format!("写入文件失败 {file_path}: {e}"))?;

            Ok(())
        }
        "system" => {
            // On Unix, we can't directly delete process environment variables
            Ok(())
        }
        _ => Err(format!("未知的环境变量来源类型: {}", conflict.source_type)),
    }
}

/// Restore environment variables from backup
pub fn restore_from_backup(backup_path: String) -> Result<(), String> {
    // Read backup file
    let content = fs::read_to_string(&backup_path).map_err(|e| format!("读取备份文件失败: {e}"))?;

    let backup_info: BackupInfo =
        serde_json::from_str(&content).map_err(|e| format!("解析备份文件失败: {e}"))?;

    // Restore each variable
    for conflict in &backup_info.conflicts {
        restore_single_env(conflict)?;
    }

    Ok(())
}

/// Restore a single environment variable
#[cfg(target_os = "windows")]
fn restore_single_env(conflict: &EnvConflict) -> Result<(), String> {
    match conflict.source_type.as_str() {
        "system" => {
            if conflict.source_path.contains("HKEY_CURRENT_USER") {
                let (hkcu, _) = RegKey::predef(HKEY_CURRENT_USER)
                    .create_subkey("Environment")
                    .map_err(|e| format!("打开注册表失败: {}", e))?;

                hkcu.set_value(&conflict.var_name, &conflict.var_value)
                    .map_err(|e| format!("恢复注册表项失败: {}", e))?;
            } else if conflict.source_path.contains("HKEY_LOCAL_MACHINE") {
                let (hklm, _) = RegKey::predef(HKEY_LOCAL_MACHINE)
                    .create_subkey(
                        "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment",
                    )
                    .map_err(|e| format!("打开系统注册表失败 (需要管理员权限): {}", e))?;

                hklm.set_value(&conflict.var_name, &conflict.var_value)
                    .map_err(|e| format!("恢复系统注册表项失败: {}", e))?;
            }
            Ok(())
        }
        _ => Err(format!(
            "无法恢复类型为 {} 的环境变量",
            conflict.source_type
        )),
    }
}

#[cfg(not(target_os = "windows"))]
fn restore_single_env(conflict: &EnvConflict) -> Result<(), String> {
    match conflict.source_type.as_str() {
        "file" => {
            // Parse file path from source_path
            let parts: Vec<&str> = conflict.source_path.split(':').collect();
            if parts.is_empty() {
                return Err("无效的文件路径格式".to_string());
            }

            let file_path = parts[0];

            // Read file content
            let mut content = fs::read_to_string(file_path)
                .map_err(|e| format!("读取文件失败 {file_path}: {e}"))?;

            // Append the environment variable line
            let export_line = format!("\nexport {}={}", conflict.var_name, conflict.var_value);
            content.push_str(&export_line);

            // Write back to file
            fs::write(file_path, content).map_err(|e| format!("写入文件失败 {file_path}: {e}"))?;

            Ok(())
        }
        _ => Err(format!(
            "无法恢复类型为 {} 的环境变量",
            conflict.source_type
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_backup_dir_creation() {
        let backup_dir = get_backup_dir();
        assert!(backup_dir.is_ok());
    }

    #[test]
    fn test_get_default_shell_config() {
        let config = get_default_shell_config();
        assert!(!config.is_empty());
    }
}

/// Get the default shell config file path for the current platform
///
/// Returns:
/// - macOS: ~/.zshrc (or ~/.bashrc if zsh not detected)
/// - Linux: ~/.bashrc
/// - Windows: "registry" (special marker)
pub fn get_default_shell_config() -> String {
    #[cfg(target_os = "windows")]
    {
        "registry".to_string()
    }

    #[cfg(not(target_os = "windows"))]
    {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());

        // Check if zsh is available (default on macOS)
        #[cfg(target_os = "macos")]
        {
            let zshrc = format!("{}/.zshrc", home);
            if std::path::Path::new(&zshrc).exists() {
                return zshrc;
            }
        }

        // Fallback to bashrc
        format!("{}/.bashrc", home)
    }
}

/// Set (add or modify) an environment variable in a shell config file
///
/// Arguments:
/// - var_name: The environment variable name
/// - var_value: The value to set
/// - target_file: Optional file path (defaults to get_default_shell_config())
///
/// Returns the file path that was modified
#[cfg(target_os = "windows")]
pub fn set_env_var(
    var_name: String,
    var_value: String,
    _target_file: Option<String>,
) -> Result<String, String> {
    use winreg::enums::*;
    use winreg::RegKey;

    // On Windows, write to HKEY_CURRENT_USER\Environment
    let hkcu = RegKey::predef(HKEY_CURRENT_USER)
        .create_subkey("Environment")
        .map_err(|e| format!("打开注册表失败: {}", e))?;

    hkcu.set_value(&var_name, &var_value)
        .map_err(|e| format!("写入注册表失败: {}", e))?;

    Ok("HKEY_CURRENT_USER\\Environment".to_string())
}

#[cfg(not(target_os = "windows"))]
pub fn set_env_var(
    var_name: String,
    var_value: String,
    target_file: Option<String>,
) -> Result<String, String> {
    let file_path = target_file.unwrap_or_else(get_default_shell_config);

    // Read existing content
    let mut content = fs::read_to_string(&file_path).unwrap_or_default();

    // Check if variable already exists
    let var_pattern = format!("export {}=", var_name);
    let mut found = false;
    let new_lines: Vec<String> = content
        .lines()
        .map(|line| {
            if line.trim().starts_with(&var_pattern) {
                found = true;
                format!("export {}=\"{}\"", var_name, var_value)
            } else {
                line.to_string()
            }
        })
        .collect();

    if found {
        // Variable existed, we updated it
        content = new_lines.join("\n");
    } else {
        // Variable doesn't exist, append it
        if !content.ends_with('\n') && !content.is_empty() {
            content.push('\n');
        }
        content.push_str(&format!("export {}=\"{}\"\n", var_name, var_value));
    }

    // Write back to file
    fs::write(&file_path, content).map_err(|e| format!("写入文件失败 {}: {}", file_path, e))?;

    Ok(file_path)
}
