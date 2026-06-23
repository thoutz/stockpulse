import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import { AdminView } from "./views/AdminView";
import "./styles/global.css";

const isAdminRoute =
  window.location.pathname === "/admin" || window.location.pathname.startsWith("/admin/");

createRoot(document.getElementById("root")!).render(
  <StrictMode>{isAdminRoute ? <AdminView /> : <App />}</StrictMode>,
);
