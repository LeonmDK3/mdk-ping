let activeIndicators = {};
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.type === "update3DIndicator") {
        if (data.show) {
            // Create or update indicator
            if (!activeIndicators[data.pingId]) {
                const indicator = document.createElement('div');
                indicator.className = 'waypoint-indicator';
                // Changed order: name first, then arrow
                indicator.innerHTML = `
                    <div class="player-name">${data.playerName}</div>
                    <div class="arrow"></div>
                `;
                document.getElementById('waypoint-container').appendChild(indicator);
                activeIndicators[data.pingId] = indicator;
            }
            
            // Update position
            const indicator = activeIndicators[data.pingId];
            indicator.style.display = 'block';
            indicator.style.left = (data.x * 100) + '%';
            indicator.style.top = (data.y * 100) + '%';
        }
    } else if (data.type === "removeIndicator") {
        if (activeIndicators[data.pingId]) {
            activeIndicators[data.pingId].remove();
            delete activeIndicators[data.pingId];
        }
    }
});