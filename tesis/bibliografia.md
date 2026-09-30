# Bibliografía

Las entradas marcadas con **✓** tienen volumen, número, páginas y año comprobados contra la fuente. Las
demás son programas, kits de diseño, hojas de datos o repositorios, que se citan por su identificador
público.

## Núcleo RISC-V y arquitectura

1. B. Levy, *FemtoRV32 / learn-fpga* — núcleos RISC-V mínimos (Quark, RV32I). <https://github.com/BrunoLevy/learn-fpga>
2. B. Levy, *FemtoRV32 DESIGN Tutorial* (episodios I–X). <https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/DESIGN>
3. B. Levy, *From Blinker to RISC-V* (tutoriales). <https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS>
4. C. Wolf (YosysHQ), *PicoRV32 — a size-optimized RISC-V CPU*. <https://github.com/YosysHQ/picorv32>
5. S. Lefebvre, *ice-v — a tiny RISC-V in Silice*. <https://github.com/sylefeb/Silice/tree/master/projects/ice-v>
6. **✓** A. Waterman y K. Asanović (eds.), *The RISC-V Instruction Set Manual, Volume I: User-Level ISA, Document Version 2.2*, mayo de 2017. — Es la edición contra la que está escrito el decodificador del FemtoRV32 empleado, que la cita explícitamente en su propio código («Table page 104 of `riscv-spec-v2.2.pdf`»). Se cita ésa y no una posterior porque es la que describe la instrucción que el circuito implementa. Nótese que las ediciones desde 2019 retitulan este volumen como *Unprivileged ISA*; la versión 2.2 conserva el nombre *User-Level ISA*.

## FPGA, kit de diseño y cadena de herramientas

7. Lattice Semiconductor, *iCE40 UltraPlus Family Data Sheet* (iCE40UP5K SG48). <https://www.latticesemi.com/iCE40UltraPlus>
8. MuseLab / wuxx, *iCESugar v1.5* — placa de desarrollo iCE40UP5K. <https://github.com/wuxx/icesugar>
9. Colorlight, *i9 (Artix-7)* — placa reutilizada como plataforma FPGA.
10. C. Wolf *et al.*, *Yosys — Open SYnthesis Suite*. <https://github.com/YosysHQ/yosys>
11. *nextpnr* — emplazamiento y ruteado portable. YosysHQ. <https://github.com/YosysHQ/nextpnr>
12. *Project IceStorm* — bitstream iCE40 (`icepack`, `iceprog`). <https://github.com/YosysHQ/icestorm>
13. *OSS CAD Suite* — distribución de herramientas. <https://github.com/YosysHQ/oss-cad-suite-build>

## Diseño digital y arquitectura de sistemas en silicio

14. **✓** C. Mead y L. Conway, *Introduction to VLSI Systems*, Addison-Wesley, 1980. — El texto que estableció el diseño estructurado: reglas escalables, separación entre diseño y fabricación, y la oblea compartida.
15. C. I. Camargo Bareño, *Diseño de Sistemas Digitales*, Universidad Nacional de Colombia, 21 de enero de 2025. Licencia Creative Commons BY-SA. — §1.2.1, «Sistemas sobre Silicio SoC», y la figura 1.3: el SoC de referencia cuyo mapa de direcciones y arquitectura de bus extiende este trabajo.

## Flujo a silicio y procesos abiertos

16. SkyWater Technology y Google, *SKY130 Open Source PDK*, 2020. Primer kit de diseño de un proceso comercial publicado sin acuerdo de confidencialidad. <https://github.com/google/skywater-pdk>
17. **✓** M. Shalan y T. Edwards, «Building OpenLANE: A 130nm OpenROAD-based Tapeout-Proven Flow», *IEEE/ACM International Conference on Computer-Aided Design (ICCAD)*, 2020.
18. *OpenLane* — implementación del flujo RTL→GDSII. <https://github.com/The-OpenROAD-Project/OpenLane>
19. *OpenROAD* — motor de emplazamiento y ruteado físico. <https://theopenroadproject.org>
20. M. Venn *et al.*, *Tiny Tapeout* — fabricación educativa de circuitos integrados. <https://tinytapeout.com>
21. *KLayout* — visor y editor de *layout* GDSII. <https://www.klayout.de>

## Detección de bordes y procesamiento de imagen

22. **✓** I. Sobel y G. Feldman, «A 3×3 Isotropic Gradient Operator for Image Processing», charla en el Stanford Artificial Intelligence Laboratory, 1968. No es una publicación formal; se describe después en Pingle (1969) y en Duda y Hart (1973), razón por la cual buena parte de la literatura la cita de forma indirecta.
23. **✓** J. M. S. Prewitt, «Object Enhancement and Extraction», en B. Lipkin y A. Rosenfeld (eds.), *Picture Processing and Psychopictorics*, Academic Press, pp. 75–149, 1970.
24. **✓** R. A. Kirsch, «Computer determination of the constituent structure of biological images», *Computers and Biomedical Research*, vol. 4, n.º 3, pp. 315–328, 1971.
25. **✓** N. Otsu, «A Threshold Selection Method from Gray-Level Histograms», *IEEE Transactions on Systems, Man, and Cybernetics*, vol. SMC-9, n.º 1, pp. 62–66, ene. 1979. Aparece también como «vol. 9»; se adopta «SMC-9», que es la numeración del índice de la revista.
26. **✓** J. Canny, «A Computational Approach to Edge Detection», *IEEE Transactions on Pattern Analysis and Machine Intelligence*, vol. PAMI-8, n.º 6, pp. 679–698, nov. 1986.
27. **✓** L. Vincent, «Morphological Grayscale Reconstruction in Image Analysis: Applications and Efficient Algorithms», *IEEE Transactions on Image Processing*, vol. 2, n.º 2, pp. 176–201, abr. 1993.
28. R. C. Gonzalez y R. E. Woods, *Digital Image Processing*, 4.ª ed., Pearson, 2018 — histéresis, umbral doble, reconstrucción morfológica y componentes conexas.

## Reconocimiento y clasificación de patrones

29. **✓** M.-K. Hu, «Visual Pattern Recognition by Moment Invariants», *IRE Transactions on Information Theory*, vol. 8, n.º 2, pp. 179–187, 1962.
30. C. K. Chow, «On Optimum Recognition Error and Reject Tradeoff», *IEEE Transactions on Information Theory*, vol. 16, n.º 1, pp. 41–46, ene. 1970. — El fundamento de la opción de rechazo del reconocedor (Capítulo 6).
31. **✓** Y. LeCun, L. Bottou, Y. Bengio y P. Haffner, «Gradient-Based Learning Applied to Document Recognition», *Proceedings of the IEEE*, vol. 86, n.º 11, pp. 2278–2324, 1998. — el conjunto MNIST.
32. G. Csurka, C. Dance, L. Fan, J. Willamowski y C. Bray, «Visual Categorization with Bags of Keypoints», *ECCV Workshop on Statistical Learning in Computer Vision*, 2004. — el *bag of visual words* original.
33. **✓** D. G. Lowe, «Distinctive Image Features from Scale-Invariant Keypoints», *International Journal of Computer Vision*, vol. 60, n.º 2, pp. 91–110, 2004.
34. **✓** N. Dalal y B. Triggs, «Histograms of Oriented Gradients for Human Detection», *IEEE Conference on Computer Vision and Pattern Recognition (CVPR)*, vol. 1, pp. 886–893, 2005.
35. **✓** S. Lazebnik, C. Schmid y J. Ponce, «Beyond Bags of Features: Spatial Pyramid Matching for Recognizing Natural Scene Categories», *IEEE CVPR*, vol. 2, pp. 2169–2178, 2006.
36. F. Pedregosa *et al.*, «Scikit-learn: Machine Learning in Python», *Journal of Machine Learning Research*, vol. 12, pp. 2825–2830, 2011. <https://scikit-learn.org>

## Aceleradores de redes neuronales

37. **✓** Y.-H. Chen, J. Emer y V. Sze, «Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for Convolutional Neural Networks», *International Symposium on Computer Architecture (ISCA)*, 2016. Existe un artículo homónimo en ISSCC 2016 sobre el mismo sistema; el que desarrolla el argumento sobre el flujo de datos es el de ISCA.
38. **✓** V. Sze, Y.-H. Chen, T.-J. Yang y J. S. Emer, «Efficient Processing of Deep Neural Networks: A Tutorial and Survey», *Proceedings of the IEEE*, vol. 105, n.º 12, pp. 2295–2329, 2017.

## Periféricos

39. OmniVision, *OV7670 CMOS VGA Image Sensor — Datasheet* (protocolo SCCB, salida YUV/RGB).
40. ILITEK, *ILI9341 — a-Si TFT LCD Single Chip Driver, 240×320 — Datasheet* (interfaz SPI); módulo PMOD-TFTLCD v1.1.

## Verificación y modelo de referencia

41. S. Williams, *Icarus Verilog* (`iverilog`, `vvp`). <https://github.com/steveicarus/iverilog>
42. T. Bybell, *GTKWave* — visor de formas de onda. <https://gtkwave.sourceforge.net>
43. C. R. Harris *et al.*, «Array programming with NumPy», *Nature*, vol. 585, pp. 357–362, 2020. <https://numpy.org>
44. P. Virtanen *et al.*, «SciPy 1.0: fundamental algorithms for scientific computing in Python», *Nature Methods*, vol. 17, pp. 261–272, 2020. <https://scipy.org>
45. J. D. Hunter, «Matplotlib: A 2D Graphics Environment», *Computing in Science & Engineering*, vol. 9, n.º 3, pp. 90–95, 2007. <https://matplotlib.org>
46. S. van der Walt *et al.*, «scikit-image: image processing in Python», *PeerJ*, vol. 2, e453, 2014. <https://scikit-image.org>

## Trabajos de comparación

47. Diana Natali Maldonado Ramírez, `tt06_grayscale_sobel` — *Gray scale and Sobel filter*, Tiny Tapeout 06, sky130, 2024. Chip fabricado y medido; es el antecedente directo de este trabajo (§2.9). <https://github.com/DianaNatali/tt06_grayscale_sobel>
48. L. Baischer, A. Leitner, B. Kulnik, S. Marschner y M. Cerv, *FPGA-Net: A Neural Network Hardware Accelerator*, proyecto universitario, Technische Universität Wien (repositorio de código, sin revisión por pares). <https://github.com/kayaleitner/FPGA_MNIST>


## Documentación de instalación del entorno

49. J. Ruiz, *RepoFinal* — manual de instalación del flujo ASIC y material del trabajo de grado. <https://github.com/JohanRuiz05/RepoFinal>
50. C. I. Camargo Bareño, *VLSI* — notas y guía de instalación de la asignatura, Universidad Nacional de Colombia. <https://github.com/cicamargoba/VLSI>

## La propuesta y los antecedentes en Colombia

Tomadas de la propuesta de este trabajo; no se cotejaron con la fuente.

51. V. A. Martínez Solarte, *Diseño de un microcontrolador con arquitectura RISC-V*, propuesta de trabajo final de Maestría en Ingeniería Electrónica (perfil profundización), director C. I. Camargo Bareño, Universidad Nacional de Colombia, 2025.
52. G. Roque R., *Desarrollo de arquitectura tipo RISC para sistemas embebidos*, tesis de maestría, Pontificia Universidad Javeriana, 2010.
53. J. A. Duque R., *Metodología integral para el emprendimiento basado en sistemas embebidos digitales en Colombia*, Universidad Nacional de Colombia, 2018.
54. D. L. Ruiz P., *Desarrollo de una estrategia pedagógica para la enseñanza de arquitecturas microprocesadas con base al núcleo RISC-V Core101*, Universidad de los Andes, 2020.
55. J. F. Camacho O., *Uso de herramientas libres para diseñar un sistema de monitoreo de variables físicas de bajo costo basado en sistemas embebidos*, Universidad Nacional de Colombia, 2020.
56. J. A. Aponte M., *Design of Fault Tolerant Embedded Systems using Approximate Computing Techniques*, Universidad Nacional de Colombia, 2023.
57. O. M. Lizcano *et al.*, *Estrategia Nacional Digital de Colombia 2023-2026*, cartel, Gobierno de Colombia, 2023. La propuesta la transcribe con los autores incompletos; se cita por su título.
