<script>
    import Item from "./Item.svelte";
    import { innerWidth, innerHeight } from "svelte/reactivity/window";
    import { releaseWakeLock, requestWakeLock } from "./wakeLock.js";
    import { isDev, isMobile, log } from "./utils";
    import { initSwipeListeners } from "./gestures/swipe.js";
    import { initMultiTap } from "./gestures/multiTap.js";
    import screenfull from "screenfull";

    let isFullscreen = $state(screenfull.isFullscreen);
    screenfull.on("change", () => (isFullscreen = screenfull.isFullscreen));

    let layout = $state({
        bgColor: null,
        rows: 1,
        columns: 1,
        items: [],
        fixedItems: [],
        icons: [],
    });
    let rowsArray = $derived(Array(layout.rows).fill(false));
    let columnsArray = $derived(Array(layout.columns).fill(false));
    let socketConnected = $state(false);

    const screenWidth = $derived(innerWidth.current);
    const screenHeight = $derived(innerHeight.current);

    const showFixedItems = $derived(layout.fixedItems.length > 0);
    var itemsPercentage = 0.85;
    var fixedPercentage = 0.15;

    const fixedContainerWidth = $derived(screenWidth * fixedPercentage);
    const fixedButtonSize = $derived(fixedContainerWidth * 0.85);

    let itemsContainerWidth = $derived(
        showFixedItems ? screenWidth * itemsPercentage : screenWidth,
    );
    const itemButtonSize = $derived(
        Math.min(
            itemsContainerWidth / layout.columns,
            screenHeight / layout.rows,
        ) * 0.9,
    );
    let htmlBgColor = $derived.by(() => {
        if (layout.bgColor == "" || layout.bgColor == undefined)
            return "616161";
        return layout.bgColor.substring(2, layout.bgColor.length);
    });

    const gridCssValue = $derived.by(() => {
        let cols = [];
        for (let i = 0; i < layout.columns; i++) cols.push("auto");
        let rows = [];
        for (let i = 0; i < layout.rows; i++) rows.push("auto");

        return rows.join(" ") + " / " + cols.join(" ");
    });

    const host = window.location.host;

    const socketUrl = isDev ? "ws://localhost:8888" : "ws://" + host;
    const socket = new WebSocket(socketUrl);

    socket.onopen = () => {
        log("Connection opened");
        socketConnected = true;
        if (isMobile) requestWakeLock();
        initMultiTap(document.documentElement, 3, screenfull.exit);
    };
    socket.onmessage = (msg) => {
        const response = JSON.parse(msg.data);

        switch (response.type) {
            case "layout":
                layout = response.data;
                log($state.snapshot(layout));
                break;

            default:
                break;
        }

        initSwipeListeners(
            document.getElementById("items"),
            () => gotoDir("main"),
            () => gotoDir("prev"),
        );
    };
    socket.onclose = () => {
        log("closed");
        socketConnected = false;
        if (isMobile) releaseWakeLock();
        screenfull.exit();
    };
    socket.onerror = (err) => {
        log("error");
        console.error(err);
        socketConnected = false;
        if (isMobile) releaseWakeLock();
        screenfull.exit();
    };

    function gotoDir(toDir) {
        if (isDev) {
            log("goto: " + toDir);
            return;
        }

        socket.send(
            JSON.stringify({
                type: "gotoDir",
                whoami: "client",
                toDir: toDir,
            }),
        );
    }

    function onItemClick(itemId, isLongPress) {
        if (isDev) {
            log(
                "onItemClick -> id: [" +
                    itemId +
                    "] / isLongPress: " +
                    isLongPress,
            );
            return;
        }

        socket.send(
            JSON.stringify({
                type: isLongPress ? "longPress" : "click",
                whoami: "client",
                itemId: itemId,
            }),
        );
    }
</script>

<main id="layout">
    {#if socketConnected}
        <div
            id="items"
            style:background-color="#{htmlBgColor}"
            style:grid={gridCssValue}
            style:flex={layout.columns}
            style:height="{screenHeight}px"
        >
            {#each rowsArray, i}
                {#each columnsArray, j}
                    <Item
                        onitemclick={onItemClick}
                        buttonSize={itemButtonSize}
                        {...layout.items[i * layout.columns + j]}
                        icons={layout.icons}
                    />
                {/each}
            {/each}
        </div>
        {#if showFixedItems}
            <div
                id="fixed-items"
                style:flex="0 0 {fixedContainerWidth}px"
                style:height="{screenHeight - 10}px"
            >
                {#each layout.fixedItems as fItem}
                    <Item
                        isFixed="true"
                        onitemclick={onItemClick}
                        buttonSize={fixedButtonSize}
                        {...fItem}
                        icons={layout.icons}
                    />
                {/each}
            </div>
        {/if}
    {:else}
        <div>::no_connection::</div>
    {/if}
</main>

<style>
    #items {
        display: grid;
        align-items: center;
        justify-content: space-evenly;
    }
    #fixed-items {
        flex: 1;
        display: grid;
        overflow-y: auto;
        padding-top: 10px;
        justify-content: center;
        border-left-color: yellow;
        border-left-style: solid;
        background-color: rgb(50, 50, 50);
    }
    main {
        display: flex;
        text-align: center;
        width: 100%;
        justify-content: space-around;
    }

    @media (min-width: 640px) {
        main {
            max-width: none;
        }
    }
</style>
