// Configuration loader for frontend
// Reads API endpoint from window location or .env file

const CONFIG = {
    API_BASE: (() => {
        // Try to use environment variable first (development)
        if (typeof process !== 'undefined' && process.env.REACT_APP_API_BASE) {
            return process.env.REACT_APP_API_BASE;
        }

        // Try to read from window.__ENV__ (injected by server at runtime)
        if (typeof window !== 'undefined' && window.__ENV__?.API_BASE) {
            return window.__ENV__.API_BASE;
        }

        // Default fallback - update this for your API endpoint
        return "https://2nn50yaz7b.execute-api.us-east-1.amazonaws.com/prod";
    })()
};

// Export for use in app.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CONFIG;
}
