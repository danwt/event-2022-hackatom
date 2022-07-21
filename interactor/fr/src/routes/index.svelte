<script lang="ts">
	import _ from 'underscore';
	const BACKEND = 'http://localhost:3001/';
	const DOUBLE_CLICK_PROTECTION_MS = 700;

	function post(data: any) {
		fetch(`${BACKEND}`, {
			method: 'POST', // or 'PUT',
			credentials: 'same-origin',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify(data)
		})
			.then((response) => response.json())
			.then((data) => {
				console.log('Success:', data);
			})
			.catch((error) => {
				console.error('Error:', error);
			});
	}

	const buttons = [
		{
			label: 'helloWorld',
			fn: () => {
				post({ kind: 'helloWorld' });
			},
			loading: false
		},
		{
			label: 'preconditions',
			fn: () => {
				post({ kind: 'preconditions' });
			},
			loading: false
		},
		{
			label: 'killAndClean',
			fn: () => {
				post({ kind: 'killAndClean' });
			},
			loading: false
		},
		{
			label: 'launch',
			fn: () => {
				post({ kind: 'launch' });
			},
			loading: false
		},
		{
			label: 'relay',
			fn: () => {
				post({ kind: 'relay' });
			},
			loading: false
		}
	];
</script>

<svelte:head>
	<title>ICS: Interactor</title>
	<meta name="description" content="A tool to interact with ICS testnet" />
</svelte:head>

<div class="artboard phone-1">
	<div class="btn-group btn-group-vertical">
		{#each buttons as b, i (i)}
			<button
				class="btn btn-wide btn-primary {b.loading ? 'loading' : ''}"
				on:click={_.debounce(
					() => {
						b.loading = true;
						b.fn();
						setTimeout(
							() => (buttons[i].loading = false),
							DOUBLE_CLICK_PROTECTION_MS
						);
					},
					DOUBLE_CLICK_PROTECTION_MS,
					true
				)}>{b.label}</button
			>
		{/each}
	</div>
</div>
