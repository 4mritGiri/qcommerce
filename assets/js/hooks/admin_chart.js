// assets/js/hooks/admin_chart.js
//
// LiveView hook for Chart.js charts in the admin dashboard.
// Usage in HEEX:
//   <canvas id="my-chart" phx-hook="AdminChart"
//           data-chart={Jason.encode!(%{type: "line", labels: [...], datasets: [...]})} />

import Chart from "chart.js/auto";

const AdminChart = {
  mounted() {
    this.renderChart();
  },

  updated() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.renderChart();
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  renderChart() {
    try {
      const config = JSON.parse(this.el.dataset.chart);
      const isDark = document.documentElement.classList.contains("dark") ||
                     getComputedStyle(document.documentElement).getPropertyValue("--adm-bg").trim() !== "";

      // Global defaults for dark-themed admin
      Chart.defaults.color = "rgba(180, 190, 210, 0.8)";
      Chart.defaults.borderColor = "rgba(255, 255, 255, 0.06)";
      Chart.defaults.font.family = "'Inter', 'SF Pro Display', sans-serif";
      Chart.defaults.font.size = 12;

      this.chart = new Chart(this.el, {
        type: config.type || "line",
        data: config.data,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: { intersect: false, mode: "index" },
          plugins: {
            legend: {
              display: config.legend !== false,
              labels: { color: "rgba(180, 190, 210, 0.8)", boxWidth: 12, padding: 16 }
            },
            tooltip: {
              backgroundColor: "rgba(15, 20, 40, 0.95)",
              borderColor: "rgba(99, 102, 241, 0.3)",
              borderWidth: 1,
              padding: 12,
              titleColor: "#e2e8f0",
              bodyColor: "rgba(180, 190, 210, 0.9)",
              cornerRadius: 8,
            }
          },
          scales: config.type === "doughnut" || config.type === "pie" ? {} : {
            x: {
              grid: { color: "rgba(255,255,255,0.04)", drawBorder: false },
              ticks: { color: "rgba(180, 190, 210, 0.6)" }
            },
            y: {
              grid: { color: "rgba(255,255,255,0.04)", drawBorder: false },
              ticks: { color: "rgba(180, 190, 210, 0.6)" },
              beginAtZero: true
            }
          },
          ...config.options
        }
      });
    } catch (e) {
      console.error("AdminChart: failed to render chart", e);
    }
  }
};

export default AdminChart;
