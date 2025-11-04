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

    function onReloadClick(_) {
        location.reload();
    }

    const host = window.location.host;

    const socketUrl = isDev ? "ws://localhost:8888" : "ws://" + host;
    const socket = new WebSocket(socketUrl);
    let socketConnected = $state(false);
    let showSplashIcon = $state(true);

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

        setTimeout(() => {
            showSplashIcon = false;
        }, 1500);
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

    const onload = (el) => {
        initSwipeListeners(
            document.getElementById("items"),
            () => gotoDir("main"),
            () => gotoDir("prev"),
        );
    };
</script>

<main
    id="layout"
    style:display={socketConnected ? "flex" : "block"}
    style:max-width="{width}px"
    style:max-height="{height}px"
>
    {#if socketConnected}
        {#if showSplashIcon}
            <svg id="icon" width="340" height="340">
                <rect
                    x="0"
                    y="0"
                    width="340"
                    height="340"
                    fill="#974493"
                    rx="5%"
                />
                <rect
                    x="14"
                    y="8"
                    width="318"
                    height="315"
                    fill="white"
                    rx="5%"
                />

                <!-- I -->
                <rect x="40" y="45" width="12" height="78" fill="#974493" />
                <!-- D -->
                <svg x="80" y="40">
                    <path
                        d="m 0,5
                            c 6.79,-1.17 15.81,-1.76 25.18,-1.76 15.11,0 24.71,2.46 32.44,7.85 8.67,5.97 14.29,15.81 14.29,30.33 0,16.16 -6.09,26.58 -13.7,32.56 -8.67,6.79 -21.67,9.72 -37.12,9.72 -10.19,0 -16.98,-0.7 -21.08,-1.41
                            v -77.29
                            z
                            m 21.2,62.07
                            c 1.05,0.23 3.04,0.23 4.45,0.23 13.7,0.23 23.89,-7.38 23.89,-25.18 0,-15.46 -9.25,-22.72 -21.9,-22.72 -3.28,0 -5.39,0.23 -6.44,0.47
                            z"
                        id="path44"
                        fill="#974493"
                    />
                </svg>
                <!-- E -->
                <svg x="180" y="45">
                    <rect x="0" y="0" width="56" height="78" fill="#974493" />
                    <polygon points="" style="fill:white;">
                        <animate
                            attributeName="points"
                            dur="1s"
                            fill="freeze"
                            from="57,5, 0,5, 0,73 57,73"
                            to="57,5, 22,15, 22,63 57,73"
                        />
                    </polygon>
                    <rect x="40" y="38" width="18" height="5" fill="#974493">
                        <animate
                            attributeName="x"
                            dur="1s"
                            fill="freeze"
                            from="10"
                            to="25"
                        />
                        <animate
                            attributeName="width"
                            dur="1s"
                            fill="freeze"
                            from="25"
                            to="18"
                        />
                    </rect>
                </svg>

                <!-- C -->
                <svg x="50" y="118">
                    <path
                        d="m 100,100
                            c -2.93,1.52 -10.42,3.28 -19.79,3.28 -29.51,0 -42.51,-18.39 -42.51,-39.35 0,-27.75 20.38,-41.93 43.92,-41.93 9.02,0 16.4,1.76 19.67,3.4
                            l -4.1,16.75
                            c -3.4,-1.41 -8.31,-2.81 -14.64,-2.81 -12.06,0 -22.6,7.14 -22.6,23.19 0,14.29 8.55,23.19 23.07,23.19 5.04,0 10.77,-0.94 14.05,-2.23
                            z"
                        fill="#974493"
                    />
                </svg>
                <!-- K -->
                <svg x="180" y="140">
                    <rect x="0" y="0" width="22" height="78" fill="#974493" />
                    <polyline points="18,38 40,0 70,0 18,58" fill="#974493" />
                    <polyline points="40,30 70,78 45,78 23,38" fill="#974493" />
                </svg>

                <!-- I -->
                <rect x="180" y="230" width="12" height="78" fill="#974493" />

                <!-- A -->
                <svg x="215" y="230" height="78">
                    <polyline
                        points="5,80 33,0 61,80"
                        fill="none"
                        stroke="#974493"
                        stroke-width="10"
                    />
                    <rect x="15" y="48" width="35" height="8" fill="#974493" />
                </svg>

                <circle r="8" cx="305" cy="300" fill="#974493" />
            </svg>
        {:else}
            <div
                use:onload
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
        {/if}
    {:else}
        <button
            id="no_connection_btn"
            title="reconnect"
            onclick={onReloadClick}
        >
            <svg id="no_connection" width="150" height="120">
                <path
                    d="M 10 40 q 65 -60 130 0 M 30 60 q 45 -45 90 0 M 50 80 q 25 -25 50 0"
                    stroke="black"
                    stroke-width="8"
                    fill="none"
                />
                <circle cx="75" cy="100" r="10" fill="black" />
                <line
                    x1="30"
                    y1="15"
                    x2="110"
                    y2="100"
                    stroke="red"
                    stroke-width="2"
                />
            </svg>
        </button>
        <p>::no_connection::</p>
    {/if}
</main>

<style>
    #no_connection_btn {
        background-color: rgba(0, 0, 0, 0);
    }
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
