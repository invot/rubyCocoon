// Cloudflare Pages middleware: asks for a password on every address of the
// `rubycoccon` Pages project except the public demo (demo.rubycoccon.pages.dev).
// That covers rubycoccon.pages.dev, main.rubycoccon.pages.dev and every
// per-deploy address. Any username is accepted; only the password is checked.
// The repository is public, so only the password's SHA-256 is stored here.

const PUBLIC_HOSTS = new Set(["demo.rubycoccon.pages.dev"]);
const PASSWORD_SHA256 = "447a489ecb85061fceb3b8f21d67f1e3ae428641fe50da406bf1a4ffc4faf3ff";
const REALM = "Ruby Cocoon";

async function sha256Hex(text) {
	const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
	return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function passwordOk(header) {
	if (!header || !header.startsWith("Basic ")) return false;
	let decoded;
	try {
		decoded = atob(header.slice(6).trim());
	} catch {
		return false;
	}
	const colon = decoded.indexOf(":");
	if (colon < 0) return false;
	// Compare fixed-length hashes so the check doesn't leak the password's length.
	return (await sha256Hex(decoded.slice(colon + 1))) === PASSWORD_SHA256;
}

export async function onRequest(context) {
	const host = new URL(context.request.url).hostname.toLowerCase();
	if (PUBLIC_HOSTS.has(host)) return context.next();
	if (await passwordOk(context.request.headers.get("Authorization"))) return context.next();
	return new Response("Password required.", {
		status: 401,
		headers: {
			"WWW-Authenticate": `Basic realm="${REALM}", charset="UTF-8"`,
			"Cache-Control": "no-store",
			"Content-Type": "text/plain; charset=utf-8",
		},
	});
}
