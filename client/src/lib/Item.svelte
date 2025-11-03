<script>
    import { isMobile } from "./utils.js";
    import { initLongPress } from "./gestures/longPress.js";

    const DEFAULT_TEXT = "";
    const DEFAULT_TEXT_SIZE = 18;
    const DEFAULT_TEXT_COLOR = "ffffffff";
    const DEFAULT_TEXT_POSITION = "bottom";
    const DEFAULT_BG_COLOR = "263238";

    let {
        isFixed,
        onitemclick,
        buttonSize,
        id,
        text,
        bgColor,
        textPosition,
        textSize,
        textColor,
        icon,
        icons,
    } = $props();

    let htmlText = $derived.by(() => {
        if (text == "" || text == undefined) return DEFAULT_TEXT;
        return recursiveModificators(text).replaceAll("\n", "<br/>");
    });

    let htmlColor = $derived.by(() => {
        if (textColor == "" || textColor == undefined)
            return DEFAULT_TEXT_COLOR;
        return textColor.substring(2, textColor.length);
    });

    let htmlBgColor = $derived.by(() => {
        if (bgColor == "" || bgColor == undefined) return DEFAULT_BG_COLOR;
        return bgColor.substring(2, bgColor.length);
    });
    let textPosClass = $derived.by(() => {
        if (textPosition == "" || textPosition == undefined)
            return "text-pos-" + DEFAULT_TEXT_POSITION;
        return "text-pos-" + textPosition;
    });
    let htmlTextSize = $derived.by(() => {
        if (textSize == "" || textSize == undefined) return DEFAULT_TEXT_SIZE;
        return textSize;
    });
    let htmlIcon = $derived.by(() => {
        if (icon == "" || icon == undefined) return "";
        const iconData = icons[icon];
        if (iconData == undefined) {
            const iconUrl = !icon.includes("base64,")
                ? "data:image/png;base64," + icon
                : icon;
            return 'url("' + iconUrl + '")';
        }

        if (iconData.includes("<svg")) {
            var b64 = encodeURIComponent(
                iconData.replace(/\<\?xml.+\?\>|\<\!DOCTYPE.+]\>/g, ""),
            )
                .replace(/%20/g, " ")
                .replace(/%3D/g, "=")
                .replace(/%3A/g, ":")
                .replace(/%2F/g, "/")
                .replace(/%22/g, "'");
            return 'url("data:image/svg+xml;charset=utf-8,' + b64 + '")';
        }

        const iconUrl = !iconData.includes("base64,")
            ? "data:image/png;base64," + iconData
            : iconData;
        return 'url("' + iconUrl + '")';
    });

    const regex = /{(.*)}/gm;
    function recursiveModificators(text) {
        const matches = text.match(regex);
        if (matches == null) return text;

        matches.forEach((m) => {
            text = text.replace(
                m,
                processModificators(m.replace("{", "").replace("}", "")),
            );
        });

        return recursiveModificators(text);
    }

    function processModificators(text) {
        var styleControl = text;
        var actualText = text;

        var isControl =
            text.startsWith("b:") ||
            text.startsWith("i:") ||
            text.startsWith("u:") ||
            text.startsWith("color.") ||
            text.startsWith("size.");
        if (isControl) {
            const colonIndex = text.indexOf(":");
            styleControl = text.substring(0, colonIndex);
            actualText = text.substring(colonIndex + 1, text.length);
        }

        if (styleControl == "b" || styleControl == "i" || styleControl == "u")
            return (
                "<" +
                styleControl +
                ">" +
                actualText +
                "</" +
                styleControl +
                ">"
            );
        if (styleControl.startsWith("emoji.")) {
            var emojis = text.replaceAll("emoji.", "").split(",");
            text = "";
            emojis.forEach(
                (emoji) => (text += "&#" + parseInt(emoji.trim(), 16) + ";"),
            );

            return text;
        }
        if (styleControl.startsWith("color."))
            return (
                '<span style="color:#' +
                styleControl.replaceAll("color.", "") +
                '">' +
                actualText +
                "</span>"
            );
        if (styleControl.startsWith("size."))
            return (
                '<span style="font-size:' +
                styleControl.replaceAll("size.", "") +
                'px;">' +
                actualText +
                "</span>"
            );

        return text;
    }

    let isLongPressed = false;

    function onclick(event) {
        if (isLongPressed) {
            isLongPressed = false;
            return;
        }

        onitemclick(id, false);
    }

    function onlongpress() {
        isLongPressed = true;
        onitemclick(id, true);
    }

    function onrightclick(_) {
        if (!isMobile) setTimeout(onclick, 2000);
    }

    function onload(b) {
        const longpressMs = 500;
        initLongPress(b, onlongpress, longpressMs);
    }
</script>

<button
    use:onload
    id="item_{id}"
    class="{textPosClass} {isFixed ? 'fixed' : ''} not-selectable"
    style:width="{buttonSize}px"
    style:height="{buttonSize}px"
    style:border-radius="{buttonSize * 0.3}px"
    style:background-color="#{htmlBgColor}"
    style:background-image={htmlIcon}
    style:background-size="{buttonSize * 0.8}px"
    {onclick}
    oncontextmenu={onrightclick}
>
    <span style:font-size="{htmlTextSize}px" style:color="#{htmlColor}">
        {@html htmlText}
    </span>
</button>

<style>
    button {
        background-color: #04aa6d;
        background-repeat: no-repeat;
        background-position: center;
        border: solid;
        border-color: white;
        color: white;
        text-align: justify;
        vertical-align: top;
        text-decoration: none;
        font-size: 16px;
        margin: 4px 2px;
        display: inline-flex;
        overflow: hidden;
        justify-content: center;
        white-space: normal;
        text-wrap: balance;
        box-shadow: 0 5px #999;
    }

    button:active {
        box-shadow: 0 3px #666;
        transform: translateY(2px);
    }

    .text-pos-top {
        align-items: start;
    }

    .text-pos-center {
        align-items: center;
    }

    .text-pos-bottom {
        align-items: end;
    }

    .fixed {
        margin-bottom: 1em;
    }

    .not-selectable {
        -webkit-touch-callout: none;
        -webkit-user-select: none;
        -khtml-user-select: none;
        -moz-user-select: none;
        -ms-user-select: none;
        user-select: none;
        -webkit-tap-highlight-color: rgba(0, 0, 0, 0); /* or transparent */
        outline: none;
    }
</style>
