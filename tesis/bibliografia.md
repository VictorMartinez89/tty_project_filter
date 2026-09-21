# Bibliografía

> **Cómo se construyó esta lista.** Reúne las **36 referencias** recopiladas a lo largo del cuaderno
> de laboratorio y las **17 verificadas contra la fuente** el 21 de septiembre de 2026 al redactar el
> Capítulo 2. Ocho obras aparecían en ambas listas y se han fundido en una sola entrada, conservando
> siempre los datos verificados; nueve son aportación de la verificación. El total son **45 entradas
> sin duplicados**.
>
> Las marcadas con **✓** tienen volumen, número, páginas y año comprobados contra la fuente. Las
> demás son programas, kits de diseño, hojas de datos o repositorios, que se citan por su
> identificador público y no admiten esa comprobación.

## Núcleo RISC-V y arquitectura

1. B. Levy, *FemtoRV32 / learn-fpga* — núcleos RISC-V mínimos (Quark, RV32I). https://github.com/BrunoLevy/learn-fpga
2. B. Levy, *FemtoRV32 DESIGN Tutorial* (episodios I–X). https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/DESIGN
3. B. Levy, *From Blinker to RISC-V* (tutoriales). https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS
4. C. Wolf (YosysHQ), *PicoRV32 — a size-optimized RISC-V CPU*. https://github.com/YosysHQ/picorv32
5. S. Lefebvre, *ice-v — a tiny RISC-V in Silice*. https://github.com/sylefeb/Silice/tree/master/projects/ice-v
6. A. Waterman y K. Asanović (eds.), *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*, RISC-V International. ⚠️ **Falta indicar la versión y el año de la edición consultada.**

## FPGA, kit de diseño y cadena de herramientas

7. Lattice Semiconductor, *iCE40 UltraPlus Family Data Sheet* (iCE40UP5K SG48). https://www.latticesemi.com/iCE40UltraPlus
8. MuseLab / wuxx, *iCESugar v1.5* — placa de desarrollo iCE40UP5K. https://github.com/wuxx/icesugar
9. Colorlight, *i9 (Artix-7)* — placa reutilizada como plataforma FPGA.
10. C. Wolf *et al.*, *Yosys — Open SYnthesis Suite*. https://github.com/YosysHQ/yosys
11. *nextpnr* — emplazamiento y ruteado portable. YosysHQ. https://github.com/YosysHQ/nextpnr
12. *Project IceStorm* — bitstream iCE40 (`icepack`, `iceprog`). https://github.com/YosysHQ/icestorm
13. *OSS CAD Suite* — distribución de herramientas. https://github.com/YosysHQ/oss-cad-suite-build

## Flujo a silicio y procesos abiertos

14. SkyWater Technology y Google, *SKY130 Open Source PDK*, 2020. Primer kit de diseño de un proceso comercial publicado sin acuerdo de confidencialidad. https://github.com/google/skywater-pdk
15. **✓** M. Shalan y T. Edwards, «Building OpenLANE: A 130nm OpenROAD-based Tapeout-Proven Flow», *IEEE/ACM International Conference on Computer-Aided Design (ICCAD)*, 2020.
16. *OpenLane* — implementación del flujo RTL→GDSII. https://github.com/The-OpenROAD-Project/OpenLane
17. *OpenROAD* — motor de emplazamiento y ruteado físico. https://theopenroadproject.org
18. M. Venn *et al.*, *Tiny Tapeout* — fabricación educativa de circuitos integrados. https://tinytapeout.com
19. *KLayout* — visor y editor de *layout* GDSII. https://www.klayout.de

## Detección de bordes y procesamiento de imagen

20. **✓** I. Sobel y G. Feldman, «A 3×3 Isotropic Gradient Operator for Image Processing», charla en el Stanford Artificial Intelligence Laboratory, 1968. ⚠️ **No es una publicación formal**; se describe después en Pingle (1969) y en Duda y Hart (1973), razón por la cual buena parte de la literatura la cita de forma indirecta.
21. **✓** J. M. S. Prewitt, «Object Enhancement and Extraction», en B. Lipkin y A. Rosenfeld (eds.), *Picture Processing and Psychopictorics*, Academic Press, pp. 75–149, 1970.
22. **✓** R. A. Kirsch, «Computer determination of the constituent structure of biological images», *Computers and Biomedical Research*, vol. 4, n.º 3, pp. 315–328, 1971.
23. **✓** N. Otsu, «A Threshold Selection Method from Gray-Level Histograms», *IEEE Transactions on Systems, Man, and Cybernetics*, vol. SMC-9, n.º 1, pp. 62–66, ene. 1979. ⚠️ Aparece también como «vol. 9»; se adopta «SMC-9», que es la numeración del índice de la revista.
24. **✓** J. Canny, «A Computational Approach to Edge Detection», *IEEE Transactions on Pattern Analysis and Machine Intelligence*, vol. PAMI-8, n.º 6, pp. 679–698, nov. 1986.
25. **✓** L. Vincent, «Morphological Grayscale Reconstruction in Image Analysis: Applications and Efficient Algorithms», *IEEE Transactions on Image Processing*, vol. 2, n.º 2, pp. 176–201, abr. 1993.
26. R. C. Gonzalez y R. E. Woods, *Digital Image Processing*, Pearson — histéresis, umbral doble, reconstrucción morfológica y componentes conexas.

## Reconocimiento y clasificación de patrones

27. **✓** M.-K. Hu, «Visual Pattern Recognition by Moment Invariants», *IRE Transactions on Information Theory*, vol. 8, n.º 2, pp. 179–187, 1962.
28. **✓** Y. LeCun, L. Bottou, Y. Bengio y P. Haffner, «Gradient-Based Learning Applied to Document Recognition», *Proceedings of the IEEE*, vol. 86, n.º 11, pp. 2278–2324, 1998. — el conjunto MNIST.
29. G. Csurka, C. Dance, L. Fan, J. Willamowski y C. Bray, «Visual Categorization with Bags of Keypoints», *ECCV Workshop on Statistical Learning in Computer Vision*, 2004. — el *bag of visual words* original.
30. **✓** D. G. Lowe, «Distinctive Image Features from Scale-Invariant Keypoints», *International Journal of Computer Vision*, vol. 60, n.º 2, pp. 91–110, 2004.
31. **✓** N. Dalal y B. Triggs, «Histograms of Oriented Gradients for Human Detection», *IEEE Conference on Computer Vision and Pattern Recognition (CVPR)*, vol. 1, pp. 886–893, 2005.
32. **✓** S. Lazebnik, C. Schmid y J. Ponce, «Beyond Bags of Features: Spatial Pyramid Matching for Recognizing Natural Scene Categories», *IEEE CVPR*, vol. 2, pp. 2169–2178, 2006.
33. F. Pedregosa *et al.*, «Scikit-learn: Machine Learning in Python», *Journal of Machine Learning Research*, vol. 12, pp. 2825–2830, 2011. https://scikit-learn.org

## Aceleradores de redes neuronales

34. **✓** Y.-H. Chen, J. Emer y V. Sze, «Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for Convolutional Neural Networks», *International Symposium on Computer Architecture (ISCA)*, 2016. ⚠️ Existe un artículo homónimo en ISSCC 2016 sobre el mismo sistema; el que desarrolla el argumento sobre el flujo de datos es el de ISCA.
35. **✓** V. Sze, Y.-H. Chen, T.-J. Yang y J. S. Emer, «Efficient Processing of Deep Neural Networks: A Tutorial and Survey», *Proceedings of the IEEE*, vol. 105, n.º 12, pp. 2295–2329, 2017.

## Periféricos

36. OmniVision, *OV7670 CMOS VGA Image Sensor — Datasheet* (protocolo SCCB, salida YUV/RGB).
37. ILITEK, *ILI9341 — a-Si TFT LCD Single Chip Driver, 240×320 — Datasheet* (interfaz SPI); módulo PMOD-TFTLCD v1.1.

## Verificación y modelo de referencia

38. S. Williams, *Icarus Verilog* (`iverilog`, `vvp`). https://github.com/steveicarus/iverilog
39. T. Bybell, *GTKWave* — visor de formas de onda. https://gtkwave.sourceforge.net
40. C. R. Harris *et al.*, «Array programming with NumPy», *Nature*, vol. 585, pp. 357–362, 2020. https://numpy.org
41. P. Virtanen *et al.*, «SciPy 1.0: fundamental algorithms for scientific computing in Python», *Nature Methods*, vol. 17, pp. 261–272, 2020. https://scipy.org
42. J. D. Hunter, «Matplotlib: A 2D Graphics Environment», *Computing in Science & Engineering*, vol. 9, n.º 3, pp. 90–95, 2007. https://matplotlib.org
43. S. van der Walt *et al.*, «scikit-image: image processing in Python», *PeerJ*, vol. 2, e453, 2014. https://scikit-image.org

## Trabajos de comparación

44. D. N. Maldonado Ramírez, *tt06_grayscale_sobel — Gray scale and Sobel filter*, Tiny Tapeout 06, sky130. https://github.com/DianaNatali/tt06_grayscale_sobel
45. L. Baischer, A. Leitner, B. Kulnik, S. Marschner y M. Cerv, *FPGA-Net: A Neural Network Hardware Accelerator*, proyecto universitario, Technische Universität Wien. https://github.com/kayaleitner/FPGA_MNIST ⚠️ **No es una publicación revisada por pares**, y así se cita en el Capítulo 2.

---

## Nota sobre el cotejo

El cruce de las dos listas produjo cuatro resultados que conviene dejar anotados.

**Ocho obras estaban en ambas listas**, y en seis de ellas la verificación corrigió o completó los
datos: la de Sobel y Feldman pasó de figurar como publicación del Stanford AI Project a declararse
como charla no publicada; la de Kirsch ganó el número de fascículo; la de Vincent recuperó el
subtítulo completo, que la lista del cuaderno había recortado; la de Lazebnik ganó volumen y páginas;
la de Otsu quedó con la numeración de volumen resuelta; y la de SkyWater incorporó el año y el rasgo
que la hace pertinente al argumento. **En los seis casos se conserva la versión verificada.**

**El caso de OpenLane requiere dos entradas y no una.** La lista del cuaderno remitía al repositorio
de código; la verificación identificó el artículo de ICCAD 2020 que describe el flujo. Son dos
objetos distintos —el programa y su descripción publicada— y el Capítulo 2 cita el segundo mientras
que los anexos usan el primero. Se mantienen separados de forma deliberada.

**Nueve referencias son aportación de la verificación** y no figuraban en el cuaderno: Hu, Prewitt,
Otsu, Lowe, Dalal y Triggs, Chen *et al.*, Sze *et al.*, Shalan y Edwards, y Baischer *et al.* Todas
ellas sostienen afirmaciones del Capítulo 2 que antes se apoyaban únicamente en el texto.

**Veintisiete de las treinta y seis no se citan en el Capítulo 2**, y eso no es un defecto: son
programas, hojas de datos y kits de diseño que sustentan los Capítulos 3 a 5 y los anexos. Se
verificó que **ninguna entrada de la tabla del Capítulo 2 queda sin citar en su cuerpo, y ninguna
cita del cuerpo queda sin entrada** en la tabla.
