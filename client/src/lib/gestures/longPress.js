class LongPress {

    /**
     * @param {HTMLElement} element
     * @param {() => void} longPressListener
     * @param {number} longPressMs
     */
    constructor(element, longPressListener, longPressMs) {
        element.removeEventListener('mousedown', this._onmousedown);
        element.removeEventListener('mouseup', this._clearTimeout);
        element.removeEventListener('mouseout', this._clearTimeout);

        element.addEventListener('mousedown', this._onmousedown);
        element.addEventListener('mouseup', this._clearTimeout);
        element.addEventListener('mouseout', this._clearTimeout);

        element.removeEventListener('touchstart', this._onmousedown)
        element.removeEventListener('touchcancel', this._clearTimeout);
        element.removeEventListener('touchend', this._clearTimeout);
        element.removeEventListener('touchmove', this._clearTimeout);

        element.addEventListener('touchstart', this._onmousedown)
        element.addEventListener('touchcancel', this._clearTimeout);
        element.addEventListener('touchend', this._clearTimeout);
        element.addEventListener('touchmove', this._clearTimeout);

        this.longPressListener = longPressListener;
        this.longPressMs = longPressMs;
    }

    /**
     * @param {Event} _e
     */
    _onmousedown = (_e) => this._timeout = setTimeout(this.longPressListener, this.longPressMs)

    /**
     * @param {Event} _e
     */
    _clearTimeout = (_e) => clearTimeout(this._timeout)
}
/**
 * @param {HTMLElement} element
 * @param {() => void} longPressListener
 * @param {number} longPressMs
 */
export function initLongPress(element, longPressListener, longPressMs) {
    new LongPress(element, longPressListener, longPressMs);
}
