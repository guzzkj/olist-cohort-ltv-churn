"""Render the static charts used in the README from the exported tables.

Usage (after scripts/run_local.py):
    python scripts/make_charts.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "outputs"
IMG_DIR = ROOT / "docs"

SURFACE, INK, INK_2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
BLUE, BLUE_DARK = "#2a78d6", "#104281"
SEQUENTIAL = LinearSegmentedColormap.from_list(
    "blue", ["#f0efec", "#cde2fb", "#86b6ef", "#3987e5", "#1c5cab", "#0d366b"]
)

plt.rcParams.update({
    "figure.facecolor": SURFACE,
    "axes.facecolor": SURFACE,
    "axes.edgecolor": GRID,
    "axes.labelcolor": INK_2,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "text.color": INK,
    "font.size": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
})


def title(ax, main, sub):
    ax.set_title(main, loc="left", fontsize=13, fontweight="bold", color=INK, pad=24)
    ax.text(0, 1.02, sub, transform=ax.transAxes, fontsize=9.5, color=INK_2)


def retention_heatmap():
    df = pd.read_csv(OUT_DIR / "cohort_retention.csv", parse_dates=["cohort_month"])
    df = df[df.month_number.between(1, 11)]
    matrix = df.pivot(index="cohort_month", columns="month_number", values="retention_pct")
    matrix.index = matrix.index.strftime("%Y-%m")

    fig, ax = plt.subplots(figsize=(10, 7))
    image = ax.imshow(matrix.values, cmap=SEQUENTIAL, aspect="auto", vmin=0, vmax=0.8)
    for (i, j), value in pd.DataFrame(matrix.values).stack().dropna().items():
        ax.text(j, i, f"{value:.2f}", ha="center", va="center", fontsize=7.5,
                color="white" if value >= 0.45 else INK_2)
    ax.set_xticks(range(len(matrix.columns)), matrix.columns)
    ax.set_yticks(range(len(matrix.index)), matrix.index)
    ax.set_xlabel("Months since first purchase")
    ax.tick_params(length=0)
    for spine in ax.spines.values():
        spine.set_visible(False)
    bar = fig.colorbar(image, ax=ax, fraction=0.03, pad=0.02)
    bar.set_label("% of cohort buying again", color=INK_2)
    bar.outline.set_visible(False)
    title(ax, "Fewer than 1% of any cohort comes back in a given month",
          "Monthly repurchase rate (%) by acquisition cohort, Jan 2017 - Aug 2018")
    fig.tight_layout()
    fig.savefig(IMG_DIR / "retention_heatmap.png", dpi=160)
    plt.close(fig)


def ltv_by_payment():
    df = pd.read_csv(OUT_DIR / "segment_ltv.csv")
    overall = df[df.payment_segment == "all"].iloc[0]
    df = df[df.payment_segment != "all"].sort_values("ltv_12m")

    fig, ax = plt.subplots(figsize=(10, 5))
    bars = ax.barh(df.payment_segment, df.ltv_12m, color=BLUE, height=0.62)
    for bar, (_, row) in zip(bars, df.iterrows()):
        ax.text(bar.get_width() + 4, bar.get_y() + bar.get_height() / 2,
                f"R$ {row.ltv_12m:,.0f}  ·  {row.repeat_rate_12m_pct:.1f}% repurchase",
                va="center", fontsize=9, color=INK_2,
                bbox=dict(facecolor=SURFACE, edgecolor="none", pad=1))
    ax.axvline(overall.ltv_12m, color=MUTED, linewidth=1, linestyle="--", zorder=0)
    ax.text(overall.ltv_12m, len(df) - 0.45, f"average R$ {overall.ltv_12m:,.0f}",
            fontsize=8.5, color=MUTED, ha="center")
    ax.set_xlim(0, df.ltv_12m.max() * 1.45)
    ax.set_xlabel("12-month LTV per customer (GMV, R$)")
    ax.tick_params(axis="y", length=0, labelcolor=INK)
    ax.grid(axis="x", color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    ax.spines["left"].set_visible(False)
    title(ax, "Customers who split the first order in 7+ installments are worth 2x",
          "12-month LTV and repurchase rate by how the first order was paid (cohorts Jan-Sep 2017)")
    fig.tight_layout()
    fig.savefig(IMG_DIR / "ltv_by_payment.png", dpi=160)
    plt.close(fig)


def repurchase_curve():
    df = pd.read_csv(OUT_DIR / "repurchase_curve.csv").sort_values("days_window")

    fig, ax = plt.subplots(figsize=(10, 4.8))
    ax.plot(df.days_window, df.pct_of_repeaters, color=BLUE, linewidth=2,
            marker="o", markersize=6, markeredgecolor=SURFACE, markeredgewidth=2)
    for days in (90, 180):
        row = df[df.days_window == days].iloc[0]
        ax.annotate(f"{row.pct_of_repeaters:.0f}% within {days} days",
                    (days, row.pct_of_repeaters), xytext=(12, -16),
                    textcoords="offset points", fontsize=9, color=BLUE_DARK)
    ax.set_ylim(0, 105)
    ax.set_xticks(df.days_window)
    ax.set_xlabel("Days after first purchase")
    ax.set_ylabel("% of second purchases")
    ax.grid(axis="y", color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    title(ax, "Most comebacks happen in the first 90 days",
          "Cumulative share of second purchases, by days since the first order")
    fig.tight_layout()
    fig.savefig(IMG_DIR / "repurchase_curve.png", dpi=160)
    plt.close(fig)


if __name__ == "__main__":
    IMG_DIR.mkdir(exist_ok=True)
    retention_heatmap()
    ltv_by_payment()
    repurchase_curve()
    print(f"charts saved to {IMG_DIR}")
