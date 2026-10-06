const tabs = document.querySelectorAll(".demo-tab");
const screens = document.querySelectorAll(".demo-screen");

tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    const view = tab.dataset.view;

    tabs.forEach((item) => {
      const isActive = item === tab;
      item.classList.toggle("active", isActive);
      item.setAttribute("aria-selected", String(isActive));
    });

    screens.forEach((screen) => {
      screen.classList.toggle("active", screen.dataset.screen === view);
    });
  });
});

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) entry.target.classList.add("is-visible");
    });
  },
  { threshold: 0.12 }
);

document.querySelectorAll(".reveal").forEach((element) => observer.observe(element));
