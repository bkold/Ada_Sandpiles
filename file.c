#include <FreeImage.h>
#include <stdio.h>
#include <unistd.h>

#define MATRIX_SIZE 3200

RGBQUAD WHITE	= {.rgbGreen = 255, .rgbRed = 255, .rgbBlue = 255};
RGBQUAD GREY	= {.rgbGreen = 183, .rgbRed = 183, .rgbBlue = 183};
RGBQUAD DARKP	= {.rgbGreen = 29,  .rgbRed = 12,  .rgbBlue = 51};
RGBQUAD PURPLE	= {.rgbGreen = 118, .rgbRed = 101, .rgbBlue = 137};

void color_map(char matrix[MATRIX_SIZE][MATRIX_SIZE]){
	FreeImage_Initialise(FALSE);

	FIBITMAP *new_picture = FreeImage_Allocate(MATRIX_SIZE, MATRIX_SIZE, 24, 0xFF0000, 0x00FF00, 0x0000FF);

	for(int i = 0; i < MATRIX_SIZE; i++){
		for(int j = 0; j < MATRIX_SIZE; j++){
			switch(matrix[i][j]){
				case 0:
					FreeImage_SetPixelColor(new_picture, i, j, &WHITE);
					break;
				case 1:
					FreeImage_SetPixelColor(new_picture, i, j, &GREY);
					break;
				case 2:
					FreeImage_SetPixelColor(new_picture, i, j, &PURPLE);
					break;
				case 3:
					FreeImage_SetPixelColor(new_picture, i, j, &DARKP);
					break;
			}
		}
	}

	FreeImage_Save(FIF_BMP, new_picture, "OUT.bmp", 0);

	FreeImage_DeInitialise();
}