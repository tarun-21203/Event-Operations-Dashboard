// Load API base URL from config (defined in config.js)
// This allows easy switching between environments without code changes
const API_BASE = CONFIG?.API_BASE || "https://2nn50yaz7b.execute-api.us-east-1.amazonaws.com/prod";

async function createEvent() {
    const preset = document.getElementById("preset").value;

    if (!preset) {
        alert("Please select an event type.");
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/events/${preset}`, {
            method: "POST"
        });

        const data = await res.json();

        const container = document.getElementById("eventCards");

        const tempCard = document.createElement("div");
        tempCard.classList.add("event-card");
        tempCard.setAttribute("data-temp-id", data.eventId);

        tempCard.innerHTML = `
            <h3>${preset.split("-")[0].toUpperCase()}</h3>
            <p><strong>Preset:</strong> ${preset}</p>
            <p><strong>Priority:</strong> Detecting...</p>
            <p><strong>Status:</strong> CREATED</p>
            <p><strong>Time:</strong> Just now</p>
        `;

        container.prepend(tempCard);

        setTimeout(() => {
            loadDashboard();
        }, 2000);

    } catch (err) {
        console.error("Error triggering event:", err);
    }
}

async function loadDashboard() {
    await Promise.all([loadEvents(), loadAnalytics()]);
}

async function loadEvents() {
    try {
        const res = await fetch(`${API_BASE}/events`);
        const events = await res.json();

        const container = document.getElementById("eventCards");

        let newHTML = "";

        events.forEach(e => {
            let priorityClass = "";
            if (e.priority === "P1") priorityClass = "p1";
            if (e.priority === "P2") priorityClass = "p2";
            if (e.priority === "P3") priorityClass = "p3";
            if (e.priority === "P4") priorityClass = "p4";

            newHTML += `
                <div class="event-card ${priorityClass}">
                    <h3>${e.eventType}</h3>
                    <p><strong>Preset:</strong> ${e.preset}</p>
                    <p><strong>Priority:</strong> ${e.priority}</p>
                    <p><strong>Status:</strong> ${e.state}</p>
                    <p><strong>Time:</strong> ${e.createdAt}</p>
                </div>
            `;
        });

        if (container.innerHTML !== newHTML) {
            container.innerHTML = newHTML;
        }

    } catch (err) {
        console.error("Error loading events:", err);
    }
}

async function loadAnalytics() {
    try {
        const res = await fetch(`${API_BASE}/analytics`);
        const data = await res.json();

        document.getElementById("totalCount").innerText = data.totalEvents || 0;
        document.getElementById("p1Count").innerText = data.byPriority?.P1 || 0;
        document.getElementById("p2Count").innerText = data.byPriority?.P2 || 0;
        document.getElementById("p3Count").innerText = data.byPriority?.P3 || 0;
        document.getElementById("p4Count").innerText = data.byPriority?.P4 || 0;

    } catch (err) {
        console.error("Error loading analytics:", err);
    }
}

window.addEventListener("DOMContentLoaded", () => {
    document.getElementById("triggerBtn")
        .addEventListener("click", createEvent);

    loadDashboard();
});

setInterval(loadDashboard, 3000);