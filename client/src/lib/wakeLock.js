
let wakelock = null;

const requestWakeLock = () => {
    // Ensure that the Wake Lock API is available
    if ('wakeLock' in navigator) {

        // Create an async function to request a wake lock
        async function _requestWakeLock() {
            try {
                // Request the screen wake lock
                wakelock = await navigator.wakeLock.request('screen');

            } catch (err) {
                // Handle the error, e.g., display a message to the user
                alert(`Could not obtain wake lock: ${err.name}, ${err.message}`)
                console.error(`Could not obtain wake lock: ${err.name}, ${err.message}`);
            }
        }

        // Automatically release the wake lock when the page is hidden
        document.addEventListener('visibilitychange', () => {
            console.log('Visibility changed');
            if (document.hidden) {
                releaseWakeLock();
            } else if (!document.hidden) {
                _requestWakeLock();
            }
        });

        // Request wake lock when needed
        _requestWakeLock();
    } else {
        // alert('Wakelock is not available');
    }
}

const releaseWakeLock = () => {
    if (wakelock !== null)
        wakelock.release().then(() => {
            console.log('Wake lock released.');
            wakelock = null;
        });
}

export { releaseWakeLock, requestWakeLock };