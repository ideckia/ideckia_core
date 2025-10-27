<script>
    import Layout from "./lib/Layout.svelte";
    import { innerWidth, innerHeight } from "svelte/reactivity/window";
    import { isDev } from "./lib/utils";
    import screenfull from "screenfull";

    let isFullscreen = $state(screenfull.isFullscreen);
    screenfull.on("change", () => (isFullscreen = screenfull.isFullscreen));
    let fullscreenUserDecisionMade = $state(false);

    window.oncontextmenu = (_) => false;
    const screenWidth = $derived(innerWidth.current);
    const screenHeight = $derived(innerHeight.current);
    const isVertical = $derived(screenWidth < screenHeight);

    function fullscreenDecision(goFullscreen) {
        if (goFullscreen) screenfull.request();
        fullscreenUserDecisionMade = true;
    }
</script>

<main>
    {#if isVertical}
        <p>::rotate_to_horizontal::</p>
        <svg id="rotation_anim" width="100" height="200">
            <rect
                x="5"
                y="10"
                width="90"
                height="180"
                rx="10"
                ry="10"
                fill="none"
                stroke="black"
                stroke-width="5"
            />
            <rect
                x="40"
                y="160"
                width="20"
                height="10"
                rx="3"
                ry="3"
                fill="black"
            />
        </svg>
    {:else if fullscreenUserDecisionMade}
        <Layout />
    {:else}
        <p>::better_exp_fullscreen::</p>
        <button onclick={() => fullscreenDecision(true)}>::yes::</button>
        <button onclick={() => fullscreenDecision(false)}>::no::</button>
    {/if}
</main>

<style>
    #rotation_anim {
        animation: rotate 2s infinite;
    }
    @keyframes rotate {
        100% {
            transform: rotate(90deg);
        }
    }
</style>
