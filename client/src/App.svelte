<script>
    import Layout from "./lib/Layout.svelte";
    import { innerWidth, innerHeight } from "svelte/reactivity/window";
    import screenfull from "screenfull";

    let fullscreenUserDecisionMade = $state(false);

    let width = $derived(innerWidth.current);
    let height = $derived(innerHeight.current);

    window.oncontextmenu = (_) => false;
    const isVertical = $derived(width < height);

    function fullscreenDecision(goFullscreen) {
        if (goFullscreen) screenfull.request();
        fullscreenUserDecisionMade = true;
    }
</script>

<main>
    {#if isVertical}
        <p>::rotate_to_horizontal::</p>
        <svg id="rotation_svg" width="100" height="200">
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
        <Layout {width} {height} />
    {:else}
        <svg id="fullscreen_svg" width="200" height="100">
            <clipPath id="mask">
                <rect x="0" y="0" width="40" height="35" />
                <rect x="160" y="0" width="40" height="35" />
                <rect x="0" y="65" width="40" height="35" />
                <rect x="160" y="65" width="40" height="35" />
            </clipPath>
            <rect
                clip-path="url(#mask)"
                x="10"
                y="5"
                width="180"
                height="90"
                fill="none"
                stroke="black"
                stroke-width="5"
            />
        </svg>
        <p>::better_exp_fullscreen::</p>
        <button onclick={() => fullscreenDecision(true)}>::yes::</button>
        <button onclick={() => fullscreenDecision(false)}>::no::</button>
    {/if}
</main>

<style>
    #rotation_svg {
        animation: rotate 2s infinite;
    }
    @keyframes rotate {
        100% {
            transform: rotate(90deg);
        }
    }
    #fullscreen_svg {
        animation: scale 2s infinite;
    }
    @keyframes scale {
        100% {
            transform: scale(1.4);
        }
    }
</style>
