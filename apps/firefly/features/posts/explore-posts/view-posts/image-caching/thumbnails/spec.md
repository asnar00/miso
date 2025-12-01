# thumbnails
*how we generate thumbnails*

Thumbnails are always square, and are generated from the original image by finding the largest square that will fit in the image, centered on the content; clipping that content out, and then scaling it down to 80x80 pixels.