//=============0428====================   
加了矩陣乘法的運算 還不完整(位元還沒標出來)  
做完矩陣乘法得到Ux Uy det 都是4x+8 bits  
input bit數可調  
//=============0427====================  
刪掉不用的東西，用imput_combined.txt當input tb  
//=============0425====================  
完成 week 9 報告中的計算順序架構:
shift registers (img1 Ix It)  
summation (Ix^2 Iy^2 IxIy IxIt IyIt)
//=============0420====================  
完成算sum(IxIt),sum(IyIt),sum(IxIy)
//=============0416====================  
寫了輸入 計算Ix Iy It 並sum(IX^2), sum(Iy^2)  





pattern.py可以生input pattern line19:random_seed(42)暫固定
sphere資料夾內有實際測資
為方便tb寫在同一檔案  
gtkwave無法看packed signal(array) 故以wire展開部分
input form:  
(Hex)img1img2  
Pixel1  
Pixel2  
.  
.  
.  
Pixel49



$$
\begin{bmatrix}
V_{x} \\ 
V_{y}
\end{bmatrix} = 
\begin{bmatrix}
\sum_{i} I_{x}(q_{i})^{2} & \sum_{i} I_{x}(q_{i})I_{y}(q_{i}) \\ 
\sum_{i} I_{y}(q_{i})I_{x}(q_{i}) & \sum_{i} I_{y}(q_{i})^{2}
\end{bmatrix}^{-1} 
\begin{bmatrix}
-\sum_{i} I_{x}(q_{i})I_{t}(q_{i}) \\ 
-\sum_{i} I_{y}(q_{i})I_{t}(q_{i})
\end{bmatrix}
$$
