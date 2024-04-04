
if (window.location.pathname.match(/options/)) {
  var buttons = document.querySelector("#menu-bar > div.right-buttons")
  if (buttons != null) {
    buttons.style.display = "none"
  }
}
