#include <stdio.h>

int mat[10000];
void main(){
   FILE* in,*out;
   in=fopen("map.txt","rt");
   out=fopen("map.bin","wb");
   int c,c1;
   fscanf(in,"%d",&c);
   fprintf(out,"%c",(char)c);
   fscanf(in,"%d",&c1);
   fprintf(out,"%c",(char)c1);
   for(int i=c1-1;i>=0;i--)
      for(int j=0;j<c;j++)
         fscanf(in,"%d",&mat[(i*c1)+j]);
   for(i=0;i<c1;i++)
      for(int j=0;j<c;j++)
         fprintf(out,"%c",mat[(i*c1)+j]);
   fclose(in);
   fclose(out);
}