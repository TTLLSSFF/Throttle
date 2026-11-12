//! Chinese font fallback for the interface.
//!
//! egui's bundled fonts carry no CJK glyphs, so translated labels and Chinese
//! application names would draw as empty boxes. The system Chinese font is
//! loaded once from \Windows\Fonts and appended as the *last* fallback of each
//! family: Latin text keeps the stock typeface, and only characters it cannot
//! draw fall through to the CJK face.
//!
//! Loading is best effort. On a Windows install without any of the candidate
//! fonts the interface still runs, just without Chinese glyphs, which is better
//! than refusing to start.

use std::sync::{Arc, LazyLock};

use eframe::egui::{Context, FontData, FontDefinitions, FontFamily};

/// Candidate files, in order of preference. `index` picks the face inside a
/// TrueType collection (`.ttc`); the plain files ignore it.
const CANDIDATES: [(&str, u32); 4] = [
    ("C:\\Windows\\Fonts\\msyh.ttc", 0),   // Microsoft YaHei
    ("C:\\Windows\\Fonts\\msyhl.ttc", 0),  // Microsoft YaHei Light
    ("C:\\Windows\\Fonts\\simhei.ttf", 0), // SimHei
    ("C:\\Windows\\Fonts\\simsun.ttc", 0), // SimSun
];

/// The first candidate that loads. `None` when none of them exist.
static CJK: LazyLock<Option<FontData>> = LazyLock::new(|| {
    CANDIDATES.iter().find_map(|(path, index)| {
        let bytes = std::fs::read(path).ok()?;
        let mut data = FontData::from_owned(bytes);
        data.index = *index;
        Some(data)
    })
});

/// Append the Chinese font to the fallback list of every family.
///
/// Call this after the families have been chosen and before `set_fonts`;
/// `appearance::apply_font` is the one place that builds families.
pub fn add_fallback(fonts: &mut FontDefinitions) {
    let Some(cjk) = CJK.as_ref() else {
        return;
    };
    let name = "cjk-fallback".to_owned();
    fonts.font_data.insert(name.clone(), Arc::new(cjk.clone()));
    for family in [FontFamily::Proportional, FontFamily::Monospace] {
        let chain = fonts.families.entry(family).or_default();
        if !chain.contains(&name) {
            chain.push(name.clone());
        }
    }
}

/// Install the stock fonts with the Chinese fallback, without a custom family
/// choice. `appearance` uses this when no font preference has been applied yet.
pub fn install(ctx: &Context) {
    let mut fonts = FontDefinitions::default();
    add_fallback(&mut fonts);
    ctx.set_fonts(fonts);
}

/// Whether a Chinese font was found on this machine.
#[cfg(test)]
fn available() -> bool {
    CJK.is_some()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fallback_is_appended_not_prepended() {
        let mut fonts = FontDefinitions::default();
        let before = fonts.families[&FontFamily::Proportional].len();
        add_fallback(&mut fonts);
        let after = &fonts.families[&FontFamily::Proportional];
        if available() {
            assert_eq!(after.len(), before + 1);
            assert_eq!(after.last().map(String::as_str), Some("cjk-fallback"));
            assert!(fonts.font_data.contains_key("cjk-fallback"));
        } else {
            assert_eq!(after.len(), before);
        }
    }

    #[test]
    fn adding_twice_does_not_duplicate() {
        let mut fonts = FontDefinitions::default();
        add_fallback(&mut fonts);
        add_fallback(&mut fonts);
        let family = &fonts.families[&FontFamily::Proportional];
        assert_eq!(
            family.iter().filter(|name| *name == "cjk-fallback").count(),
            usize::from(available())
        );
    }
}
