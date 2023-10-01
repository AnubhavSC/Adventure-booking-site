function toggleMenu() {
    var menu = document.querySelector('.menu');
    var menuButton = document.querySelector('.menu-button');

    if (menu.style.display === 'block') {
        menu.style.display = 'none';
    } else {
        menu.style.display = 'block';
    }
}

