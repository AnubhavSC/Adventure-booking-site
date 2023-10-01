function toggleMenu() {
    var menu = document.querySelector('.menu');
    var menuButton = document.querySelector('.menu-button');

    if (menu.style.display === 'block') {
        menu.style.display = 'none';
    } else {
        menu.style.display = 'block';
    }
}

// loading spinner
window.addEventListener('load', function () {
    setTimeout(function () {
        const preloader = document.getElementById('preloader');
        preloader.style.display = 'none';
        const content = document.getElementById('content');
        content.style.display = 'block';
    }, 1000); 
});
