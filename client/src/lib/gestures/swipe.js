
import { isMobile } from '../utils';

var initialPosX, initialPosY, finalPosX, finalPosY;
var swipeThreshold = 100;

function isSwipeRight() {
    const horizontalDistance = finalPosX - initialPosX;
    const verticalDistance = finalPosY - initialPosY;

    if (Math.abs(horizontalDistance) > Math.abs(verticalDistance) && Math.abs(horizontalDistance) > swipeThreshold)
        if (finalPosX - initialPosX > 0)
            return true;

    return false;
}

function isSwipeUp() {
    const horizontalDistance = finalPosX - initialPosX;
    const verticalDistance = finalPosY - initialPosY;

    if (Math.abs(horizontalDistance) < Math.abs(verticalDistance) && Math.abs(verticalDistance) > swipeThreshold)
        if (finalPosY - initialPosY < 0)
            return true;

    return false;
}

function handleGesture() {
    const isRight = isSwipeRight();
    const isUp = isSwipeUp();

    if (!isRight && !isUp)
        return;

    if (isUp && _swipeUpListener !== null)
        _swipeUpListener();

    if (isRight && _swipeRightListener !== null)
        _swipeRightListener();
}

/**
 * @param {number} x
 * @param {number} y
 */
function setInitPos(x, y) {
    initialPosX = x;
    initialPosY = y;
}

/**
 * @param {number} x
 * @param {number} y
 */
function setFinalPos(x, y) {
    finalPosX = x;
    finalPosY = y;
    handleGesture();
}

/**
 * @param {MouseEvent} event
 */
function setInitMouse(event) {
    setInitPos(event.clientX, event.clientY);
}

/**
 * @param {MouseEvent} event
 */
function setFinalMouse(event) {
    setFinalPos(event.clientX, event.clientY);
}

/**
 * @param {TouchEvent} event
 */
function setInitTouch(event) {
    setInitPos(event.changedTouches[0].clientX, event.changedTouches[0].clientY);
}

/**
 * @param {TouchEvent} event
 */
function setFinalTouch(event) {
    setFinalPos(event.changedTouches[0].clientX, event.changedTouches[0].clientY);
}

/**
 * @param {HTMLElement} element
 */
function addListeners(element) {
    if (isMobile) {
        element.addEventListener('touchstart', setInitTouch);
        element.addEventListener('touchend', setFinalTouch);
    } else {
        element.addEventListener('mousedown', setInitMouse);
        element.addEventListener('mouseup', setFinalMouse);
    }
}

/**
 * @param {HTMLElement} element
 */
function removeListeners(element) {
    if (isMobile) {
        element.removeEventListener('touchstart', setInitTouch);
        element.removeEventListener('touchend', setFinalTouch);
    } else {
        element.removeEventListener('mousedown', setInitMouse);
        element.removeEventListener('mouseup', setFinalMouse);
    }
}

let _swipeUpListener;
let _swipeRightListener;

/**
 * @param {HTMLElement} element
 * @param {() => void} swipeUpListener
 * @param {() => void} swipeRightListener
 */
export function initSwipeListeners(element, swipeUpListener, swipeRightListener) {
    removeListeners(element);
    addListeners(element);
    _swipeUpListener = swipeUpListener;
    _swipeRightListener = swipeRightListener;
}
