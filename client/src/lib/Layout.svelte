<svelte:options customElement="ideckia-layout" />

<script>
    import Item from "./Item.svelte";
    import { innerWidth, innerHeight } from "svelte/reactivity/window";
    import { releaseWakeLock, requestWakeLock } from "./wakeLock.js";
    import { isDev, isMobile, log } from "./utils";
    import { initSwipeListeners } from "./gestures/swipe.js";
    import { initMultiTap } from "./gestures/multiTap.js";
    import screenfull from "screenfull";
    import { createEventDispatcher } from "svelte";

    let {
        width = innerWidth.current,
        height = innerHeight.current,
        callServer = "true",
    } = $props();

    const dispatch = createEventDispatcher();

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

    const showFixedItems = $derived(layout.fixedItems.length > 0);
    var itemsPercentage = 0.85;
    var fixedPercentage = 0.15;

    const fixedContainerWidth = $derived(width * fixedPercentage);
    const fixedButtonSize = $derived(fixedContainerWidth * 0.85);

    let itemsContainerWidth = $derived(
        showFixedItems ? width * itemsPercentage : width,
    );
    const itemButtonSize = $derived(
        Math.min(itemsContainerWidth / layout.columns, height / layout.rows) *
            0.9,
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

        dispatch("onItemClick", {
            itemId: itemId,
        });

        if (callServer == "true")
            socket.send(
                JSON.stringify({
                    type: isLongPress ? "longPress" : "click",
                    whoami: "client",
                    itemId: itemId,
                }),
            );
    }
</script>

<main
    id="layout"
    style:display={socketConnected ? "flex" : "block"}
    style:max-width="{width}px"
    style:max-height="{height}px"
>
    {#if socketConnected}
        <div
            id="items"
            style:background-color="#{htmlBgColor}"
            style:grid={gridCssValue}
            style:flex={layout.columns}
            style:height="{height}px"
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
                style:height="{height - 10}px"
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
        <svg id="no_connection" width="190" height="160">
            <path
                d="M 10 60 q 85 -70 170 0 M 30 80 q 65 -55 130 0 M 50 100 q 45 -40 90 0"
                stroke="black"
                stroke-width="8"
                fill="none"
            />
            <circle cx="95" cy="125" r="10" fill="black" />
            <line
                x1="40"
                y1="20"
                x2="140"
                y2="130"
                stroke="red"
                stroke-width="2"
            />
        </svg>
        <p>::no_connection::</p>
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
