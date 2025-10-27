export const isDev = import.meta.env.MODE == "development";
// @ts-ignore
export const isMobile = (('ontouchstart' in window) || (navigator.maxTouchPoints > 0) || (navigator.msMaxTouchPoints > 0));

export function log(v) {
    if (!isDev)
        return;
    console.log(v);
}
