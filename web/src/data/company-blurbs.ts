export const companyBlurbs: Record<string, string> = {
  NVDA:
    "NVIDIA designs GPUs and AI accelerators powering data centers, gaming, and autonomous systems. The dominant chip supplier for large language model training and inference.",
  AMD: "Advanced Micro Devices competes with NVIDIA in GPUs and Intel in CPUs. Key beneficiary when NVDA earnings lift the broader semiconductor trade.",
  AVGO:
    "Broadcom supplies networking chips and custom ASICs for hyperscale AI infrastructure. Often moves in sympathy with NVDA on AI capex cycles.",
  RKLB:
    "Rocket Lab is a leading small-launch provider and space systems company. Frequently tracked as a SpaceX IPO proxy and launch-sector bellwether.",
  ASTS:
    "AST SpaceMobile aims to deliver space-based cellular broadband directly to unmodified phones. Satellite connectivity play in the space ripple network.",
  LUNR:
    "Intuitive Machines builds lunar landers and infrastructure for NASA's Artemis program. Part of the lunar/space ripple cluster around launch catalysts.",
  RDW:
    "Redwire manufactures space infrastructure components and deployable systems. Aerospace components supplier tied to commercial space growth.",
  HWM:
    "Howmet Aerospace produces advanced engine components and structures for aerospace and defense. Benefits from increased launch and satellite activity.",
  TSLA:
    "Tesla builds EVs, energy storage, and develops FSD/robotics. Often used as a high-beta growth proxy alongside space and tech names.",
  SPY: "Tracks the S&P 500 — 500 large-cap US companies across every major sector.",
  QQQ: "Tracks the Nasdaq-100 — mega-cap tech and growth names that drive risk appetite.",
};

export function companyBlurb(ticker: string): string | undefined {
  return companyBlurbs[ticker.toUpperCase()];
}
