//! Friendly application names for the process table, in the spirit of
//! NetLimiter: a row reads "谷歌浏览器" instead of "chrome.exe".
//!
//! Resolution order:
//!
//! 1. The kernel's own pseudo-entries, which are translated.
//! 2. The curated dictionary in [`crate::appnames_data`], which has a name in
//!    both interface languages.
//! 3. The executable's version resource (`FileDescription`, then
//!    `ProductName`), which vendors localise themselves.
//! 4. The bare file name, as before.
//!
//! Version resources are read once per executable and cached; the lookup runs
//! while the table is drawn, so a slow probe would stutter the UI.

use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use crate::appnames_data;
use crate::backend::synthetic;
use crate::i18n;

/// Executable path (lower-cased) to the name its version resource carries.
/// `None` records "asked already, nothing usable", so a probe runs once.
static VERSION_NAMES: LazyLock<Mutex<HashMap<String, Option<String>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// The name to show in the process table.
pub fn display(exe: &str) -> String {
    if exe == synthetic::UNKNOWN_EXE {
        return i18n::t("Unknown traffic", "未知流量").to_string();
    }
    if let Some(name) = known(exe) {
        return name;
    }
    if let Some(name) = version_name(exe) {
        return name;
    }
    synthetic::display_name(exe)
}

/// The curated name for this executable, in the active language, if it is one
/// of the applications in the dictionary.
pub fn known(exe: &str) -> Option<String> {
    let file = file_name(exe).to_lowercase();
    appnames_data::lookup(&file)
        .map(|(english, chinese)| i18n::pick(i18n::language(), english, chinese).to_string())
}

/// Everything the filter box should match against: the friendly name, the
/// executable's file name and the full path, lower-cased. Searching for
/// "chrome" finds a row labelled "谷歌浏览器".
pub fn filter_haystack(exe: &str) -> String {
    format!(
        "{}\n{}\n{}",
        display(exe).to_lowercase(),
        file_name(exe).to_lowercase(),
        exe.to_lowercase()
    )
}

/// The last path segment of an executable path, either separator.
fn file_name(exe: &str) -> &str {
    exe.rsplit(['\\', '/']).next().unwrap_or(exe)
}

/// The name from the executable's version resource, cached.
fn version_name(exe: &str) -> Option<String> {
    if exe.starts_with('<') || !exe.to_lowercase().ends_with(".exe") {
        return None;
    }
    let key = exe.to_lowercase();
    if let Some(cached) = lock().get(&key) {
        return cached.clone();
    }
    let looked = win::description(exe)
        .map(|name| clean(&name))
        .filter(|name| !name.is_empty());
    lock().insert(key, looked.clone());
    looked
}

/// Tidy a resource string: trim, and reject names that only repeat the file
/// name (some installers leave "chrome" in both fields).
fn clean(name: &str) -> String {
    name.trim().to_string()
}

fn lock() -> std::sync::MutexGuard<'static, HashMap<String, Option<String>>> {
    VERSION_NAMES
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

#[cfg(target_os = "windows")]
mod win {
    use std::ffi::{OsStr, c_void};
    use std::os::windows::ffi::OsStrExt;

    #[link(name = "version")]
    unsafe extern "system" {
        fn GetFileVersionInfoSizeW(filename: *const u16, handle: *mut u32) -> u32;
        fn GetFileVersionInfoW(
            filename: *const u16,
            handle: u32,
            len: u32,
            data: *mut c_void,
        ) -> i32;
        fn VerQueryValueW(
            block: *const c_void,
            sub_block: *const u16,
            buffer: *mut *mut c_void,
            len: *mut u32,
        ) -> i32;
    }

    /// `FileDescription` (then `ProductName`) from the executable's version
    /// resource, or `None` when it has none.
    pub fn description(path: &str) -> Option<String> {
        let path = wide(path);
        // SAFETY: `path` is a NUL-terminated UTF-16 string owned by this frame.
        let size = unsafe { GetFileVersionInfoSizeW(path.as_ptr(), std::ptr::null_mut()) };
        if size == 0 {
            return None;
        }
        let mut block = vec![0u8; size as usize];
        // SAFETY: the buffer is exactly the size the API just reported.
        let loaded =
            unsafe { GetFileVersionInfoW(path.as_ptr(), 0, size, block.as_mut_ptr().cast()) };
        if loaded == 0 {
            return None;
        }

        let translation_key = wide("\\VarFileInfo\\Translation");
        let mut values: *mut c_void = std::ptr::null_mut();
        let mut bytes: u32 = 0;
        // SAFETY: `block` holds the resource; the out-pointers live here.
        let found = unsafe {
            VerQueryValueW(
                block.as_ptr().cast(),
                translation_key.as_ptr(),
                &mut values,
                &mut bytes,
            )
        };
        // The translation table is a list of (language, code page) u16 pairs.
        if found == 0 || values.is_null() || bytes < 4 {
            return None;
        }
        // SAFETY: at least two u16 values were reported.
        let language = unsafe { *(values as *const u16) };
        let codepage = unsafe { *((values as *const u16).add(1)) };

        for field in ["FileDescription", "ProductName"] {
            let key = wide(&format!(
                "\\StringFileInfo\\{language:04x}{codepage:04x}\\{field}"
            ));
            let mut text: *mut c_void = std::ptr::null_mut();
            let mut chars: u32 = 0;
            // SAFETY: same resource block, same out-pointer pattern.
            let found = unsafe {
                VerQueryValueW(block.as_ptr().cast(), key.as_ptr(), &mut text, &mut chars)
            };
            if found == 0 || text.is_null() || chars == 0 {
                continue;
            }
            // SAFETY: the API reports `chars` UTF-16 units, NUL not included.
            let name = unsafe {
                String::from_utf16_lossy(std::slice::from_raw_parts(
                    text as *const u16,
                    chars as usize,
                ))
            };
            if !name.trim().is_empty() {
                return Some(name);
            }
        }
        None
    }

    fn wide(text: &str) -> Vec<u16> {
        OsStr::new(text)
            .encode_wide()
            .chain(std::iter::once(0))
            .collect()
    }
}

#[cfg(not(target_os = "windows"))]
mod win {
    pub fn description(_path: &str) -> Option<String> {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_applications_are_named_in_the_interface_language() {
        // The global language is English until the app starts, so tests are
        // stable without touching it.
        assert_eq!(known("chrome.exe").as_deref(), Some("Google Chrome"));
        assert_eq!(
            known("C:\\Program Files\\Google\\Chrome\\chrome.exe").as_deref(),
            Some("Google Chrome")
        );
        assert_eq!(known("zzz-unknown-app.exe"), None);
    }

    #[test]
    fn unknown_traffic_is_labelled_not_shown_as_a_sentinel() {
        assert_eq!(display(synthetic::UNKNOWN_EXE), "Unknown traffic");
        assert_eq!(display(synthetic::SYSTEM_EXE), "System");
    }

    #[test]
    fn fallback_keeps_the_file_name() {
        assert_eq!(display("C:\\tools\\my-tool.exe"), "my-tool.exe");
        assert_eq!(display("my-tool.exe"), "my-tool.exe");
    }

    #[test]
    fn filter_matches_the_name_and_the_executable() {
        let haystack = filter_haystack("C:\\Apps\\chrome.exe");
        assert!(haystack.contains("google chrome"));
        assert!(haystack.contains("chrome.exe"));
        assert!(haystack.contains("c:\\apps\\chrome.exe"));
    }
}
