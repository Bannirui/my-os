//
// Created by dingrui on 2023/7/15.
//
void Start_Kernel (void)
{
  int *addr = (int *)0xffff800000a00000;
  char arr[4][4] = {{ 0x00, 0x00, 0xff, 0x00 },
					{ 0x00, 0xff, 0x00, 0x00 },
					{ 0xff, 0x00, 0x00, 0x00 },
					{ 0xff, 0xff, 0xff, 0x00 }};
  for (int i = 0; i < 4; ++i)
	{
	  for (int j = 0; j < 1440 * 20; ++j)
		{
		  for (int k = 0; k < 4; ++k)
			{
			  *((char *)addr + k) = arr[i][k];
			}
		  addr++;
		}
	}

  while (1);
}