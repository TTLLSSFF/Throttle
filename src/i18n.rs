//! UI language: the English source strings, a Simplified Chinese translation,
//! and the helpers the rest of the crate uses to pick between them.
//!
//! Translations live at the call site — `t("Settings", "设置")` — instead of in a
//! central table. A string used by the interface is therefore translated where
//! it is written, and a forgotten translation is visible in review rather than
//! silently falling back to English. The active language is resolved once at
//! start-up (the persisted preference, or the Windows display language when the
//! preference is "follow system") and read from a global afterwards.
//!
//! `t` returns `&'static str`, so call sites can hand the result straight to
//! egui without allocating. `tf` and `count` cover sentences with values in
//! them, whose word order differs between the two languages.
//!
//! The CJK font fallback lives here too: Chinese process and application names
//! must render even when the interface itself is English.

use std::sync::atomic::{AtomicU8, Ordering};

use serde::{Deserialize, Deserializer, Serialize, Serializer};

/// The language the user asked for, as stored in `settings.json`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum Language {
    /// Follow the Windows display language.
    #[default]
    Auto,
    English,
    /// Simplified Chinese.
    Chinese,
}

impl Language {
    /// Every choice, in menu order.
    pub const ALL: [Self; 3] = [Self::Auto, Self::English, Self::Chinese];

    /// Menu label. The two concrete languages are written in themselves, as
    /// language pickers conventionally do; the automatic choice is translated.
    pub fn label(self) -> &'static str {
        match self {
            Self::Auto => t("Follow system", "跟随系统"),
            Self::English => "English",
            Self::Chinese => "简体中文",
        }
    }

    /// The value stored in `settings.json`.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Auto => "auto",
            Self::English => "english",
            Self::Chinese => "chinese",
        }
    }

    /// Parse the stored value. Anything unknown means "follow system", so a
    /// file written by a newer build never loses the other settings.
    pub fn from_str(value: &str) -> Self {
        match value {
            "english" => Self::English,
            "chinese" => Self::Chinese,
            _ => Self::Auto,
        }
    }
}

impl Serialize for Language {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(self.as_str())
    }
}

impl<'de> Deserialize<'de> for Language {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let stored = String::deserialize(deserializer)?;
        Ok(Self::from_str(&stored))
    }
}

/// The language actually used to draw the interface.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Lang {
    English,
    Chinese,
}

const ENGLISH: u8 = 0;
const CHINESE: u8 = 1;

/// The active language, as an [`AtomicU8`] so every thread agrees.
static ACTIVE: AtomicU8 = AtomicU8::new(ENGLISH);

/// Resolve a stored preference to the language to use now.
pub fn resolve(requested: Language) -> Lang {
    match requested {
        Language::English => Lang::English,
        Language::Chinese => Lang::Chinese,
        Language::Auto if system_is_chinese() => Lang::Chinese,
        Language::Auto => Lang::English,
    }
}

/// Set the language used by every following `t`/count call.
pub fn set_language(requested: Language) {
    let lang = resolve(requested);
    ACTIVE.store(
        match lang {
            Lang::English => ENGLISH,
            Lang::Chinese => CHINESE,
        },
        Ordering::Relaxed,
    );
}

/// The language in use now.
pub fn language() -> Lang {
    if ACTIVE.load(Ordering::Relaxed) == CHINESE {
        Lang::Chinese
    } else {
        Lang::English
    }
}

/// Pick the string for `lang`. The pure form, for tests and callers that
/// already know the language.
pub fn pick(lang: Lang, english: &'static str, chinese: &'static str) -> &'static str {
    match lang {
        Lang::English => english,
        Lang::Chinese => chinese,
    }
}

/// The string for the active language: `t("Settings", "设置")`.
pub fn t(english: &'static str, chinese: &'static str) -> &'static str {
    pick(language(), english, chinese)
}

/// Replace every `{name}` placeholder in `text` with the matching value.
pub fn fill(text: &str, args: &[(&str, &str)]) -> String {
    let mut out = text.to_string();
    for (name, value) in args {
        out = out.replace(&format!("{{{name}}}"), value);
    }
    out
}

/// A sentence with values in it, translated as a whole so the word order can
/// differ between languages: `tf("{n} flows", "{n} 条连接", &[("n", "3")])`.
pub fn tf(english: &'static str, chinese: &'static str, args: &[(&str, &str)]) -> String {
    fill(t(english, chinese), args)
}

/// A count plus its unit, with English pluralisation:
/// `count(1, "process", "processes", "个进程")` → "1 process" / "1 个进程".
pub fn count(
    n: usize,
    english_one: &'static str,
    english_many: &'static str,
    chinese: &'static str,
) -> String {
    match language() {
        Lang::English => {
            let unit = if n == 1 { english_one } else { english_many };
            format!("{n} {unit}")
        }
        Lang::Chinese => format!("{n} {chinese}"),
    }
}

/// The Windows display language is Chinese (any script; the translation is
/// Simplified Chinese either way).
#[cfg(target_os = "windows")]
fn system_is_chinese() -> bool {
    // LANGID: the low 10 bits are the primary language, 0x04 for Chinese.
    let lang_id = unsafe { windows::Win32::Globalization::GetUserDefaultUILanguage() };
    lang_id & 0x3ff == 0x04
}

#[cfg(not(target_os = "windows"))]
fn system_is_chinese() -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn language_round_trips_through_its_stored_names() {
        for language in Language::ALL {
            let json = serde_json::to_string(&language).unwrap();
            assert_eq!(json, format!("\"{}\"", language.as_str()));
            let back: Language = serde_json::from_str(&json).unwrap();
            assert_eq!(back, language);
        }
    }

    #[test]
    fn unknown_stored_language_follows_the_system() {
        let back: Language = serde_json::from_str("\"klingon\"").unwrap();
        assert_eq!(back, Language::Auto);
        assert_eq!(Language::from_str(""), Language::Auto);
        assert_eq!(Language::default(), Language::Auto);
    }

    #[test]
    fn explicit_languages_resolve_to_themselves() {
        assert_eq!(resolve(Language::English), Lang::English);
        assert_eq!(resolve(Language::Chinese), Lang::Chinese);
    }

    #[test]
    fn pick_reads_the_requested_translation() {
        assert_eq!(pick(Lang::English, "Down", "下行"), "Down");
        assert_eq!(pick(Lang::Chinese, "Down", "下行"), "下行");
    }

    #[test]
    fn fill_replaces_every_named_placeholder() {
        let text = fill("{n} of {total} processes", &[("n", "3"), ("total", "12")]);
        assert_eq!(text, "3 of 12 processes");
    }

    #[test]
    fn count_pluralises_english_and_keeps_chinese_flat() {
        // `count` reads the global, which is English until the app starts.
        assert_eq!(count(1, "process", "processes", "个进程"), "1 process");
        assert_eq!(count(0, "process", "processes", "个进程"), "0 processes");
        assert_eq!(count(12, "flow", "flows", "条连接"), "12 flows");
    }
}
