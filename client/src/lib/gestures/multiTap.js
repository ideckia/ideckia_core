import { isMobile } from "../utils";
/**
 * @param {TouchEvent} event
 */
function ontouchstart(event) {
    if (event.touches.length >= _touchCount)
        _multiTapListener();
}

let _multiTapListener;
let _touchCount;
/**
 * @param {HTMLElement} element
 * @param {() => void} multiTapListener
 */
export function initMultiTap(element, touchCount, multiTapListener) {
    if (!isMobile)
        return;

    element.removeEventListener("touchstart", ontouchstart);
    element.addEventListener("touchstart", ontouchstart);
    _multiTapListener = multiTapListener;
    _touchCount = touchCount;
}