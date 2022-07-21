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

	function kill() {
		post({ kind: 'kill' });
	}

	function launch() {
		console.log(`launch`);
	}

	const buttons = [
		{
			label: 'kill',
			fn: kill,
			loading: false
		},
		{
			label: 'launch',
			fn: launch,
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
				class="btn {b.loading ? 'loading' : ''}"
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
