using System;
using System.Text.RegularExpressions;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Single defensive cleanup point for every string before it reaches Tolk.
    /// Malformed markup, pathological regex input or a future cleanup bug must
    /// never suppress speech: on any failure, the original text is returned.
    /// </summary>
    internal static class TextCleaner
    {
        private static readonly TimeSpan RegexTimeout = TimeSpan.FromMilliseconds(50);
        private const RegexOptions CommonOptions =
            RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase;

        private static readonly Regex BbCodeImage = new(
            @"\[img(?:=[^\]]*)?\].*?\[/img\]",
            CommonOptions | RegexOptions.Singleline,
            RegexTimeout);

        // tooltip_nav.js replaces known image-only labels with semantic markers
        // after reading the rendered DOM. Resolve those markers here, the single
        // cleanup point, so every added word remains localizable through L10n.
        private static readonly Regex TooltipIcon = new(
            @"\[\[ub-icon:([a-z0-9_-]+)\]\]",
            CommonOptions,
            RegexTimeout);

        private static readonly Regex BbCodeParagraph = new(
            @"\[(?:/?p(?:=[^\]]*)?|br)\]",
            CommonOptions,
            RegexTimeout);

        private static readonly Regex BbCodeFormatting = new(
            @"\[/?(?:color|i|b)(?:=[^\]]*)?\]",
            CommonOptions,
            RegexTimeout);

        // <br> and <p> both mark a line/paragraph boundary. XBBCODE wraps event
        // and origin descriptions in <p class="...">...</p>, so these must become
        // newlines, not vanish — otherwise paragraphs run together when spoken.
        private static readonly Regex HtmlBreak = new(
            @"<br\s*/?>|</?p\b[^>]*>",
            CommonOptions,
            RegexTimeout);

        // Deliberately a whitelist of tags the UI could plausibly emit, not
        // <[^>]+>: game text contains literal angle brackets, and a catch-all
        // silently eats them along with the words in between.
        private static readonly Regex HtmlTag = new(
            @"</?(?:div|span|font|img|strong|em)\b[^>]*>",
            CommonOptions,
            RegexTimeout);

        private static readonly Regex HorizontalWhitespace = new(
            @"[\t\f\v ]+",
            RegexOptions.Compiled | RegexOptions.CultureInvariant,
            RegexTimeout);

        private static readonly Regex WhitespaceAroundNewline = new(
            @"[\t ]*\n[\t ]*",
            RegexOptions.Compiled | RegexOptions.CultureInvariant,
            RegexTimeout);

        private static readonly Regex ExcessBlankLines = new(
            @"\n{3,}",
            RegexOptions.Compiled | RegexOptions.CultureInvariant,
            RegexTimeout);

        internal static string Clean(string text)
        {
            if (string.IsNullOrEmpty(text)) return text;

            try
            {
                // No HtmlDecode here: un-escaping belongs to the transport that
                // did the escaping (LogBridge, for log.html). Decoding twice
                // would turn escaped angle brackets back into apparent markup.
                string cleaned = BbCodeImage.Replace(text, " ");
                cleaned = TooltipIcon.Replace(cleaned,
                    match => L10n.T("tooltip.icon." + match.Groups[1].Value));
                cleaned = BbCodeParagraph.Replace(cleaned, "\n");
                cleaned = BbCodeFormatting.Replace(cleaned, "");
                cleaned = HtmlBreak.Replace(cleaned, "\n");
                cleaned = HtmlTag.Replace(cleaned, "");
                cleaned = cleaned.Replace("\r\n", "\n", StringComparison.Ordinal);
                cleaned = cleaned.Replace('\r', '\n');
                cleaned = cleaned.Replace('\u00a0', ' ');
                cleaned = HorizontalWhitespace.Replace(cleaned, " ");
                cleaned = WhitespaceAroundNewline.Replace(cleaned, "\n");
                cleaned = ExcessBlankLines.Replace(cleaned, "\n\n");
                return cleaned.Trim();
            }
            catch
            {
                return text;
            }
        }
    }
}
