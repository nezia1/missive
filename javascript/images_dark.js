// Function to change images from light to dark
function fromLightToDark(images) {
    images.forEach(image => {
        if (!image.src.includes("_dark")) {
            var idx = image.src.lastIndexOf('.');
            if (idx > -1) {
                var add = "_dark";
                image.src = [image.src.slice(0, idx), add, image.src.slice(idx)].join('');
            }
        }
    });
}

// Function to change images from dark to light
function fromDarkToLight(images) {
    images.forEach(image => {
        if (image.src.includes("_dark")) {
            image.src = image.src.replace("_dark", "");
        }
    });
}

// Function to update images based on the current theme
function updateImagesBasedOnTheme() {
    var darkables = document.querySelectorAll('img[src$="darkable"]');
    const darkModeOn = document.body.getAttribute('data-md-color-scheme') === 'slate';

    if (darkModeOn)
        fromLightToDark(darkables);
    else
        fromDarkToLight(darkables);
}

// Initial check based on data-md-color-scheme attribute
updateImagesBasedOnTheme();

// Listen for changes to prefers-color-scheme
const darkModeMediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
darkModeMediaQuery.addListener((e) => {
    const darkModeOn = e.matches;
    var darkables = document.querySelectorAll('img[src$="darkable"]');

    if (darkModeOn)
        fromLightToDark(darkables);
    else
        fromDarkToLight(darkables);
    console.log(`Dark mode is ${darkModeOn ? '🌒 on' : '☀️ off'}.`);
});

// Observe changes to the data-md-color-scheme attribute
const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'data-md-color-scheme') {
            updateImagesBasedOnTheme();
        }
    });
});

// Start observing the body element for attribute changes
observer.observe(document.body, { attributes: true });
