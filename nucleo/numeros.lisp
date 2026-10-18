;;;; Los numeros del lenguaje.
;;;;
;;;; DECISION (2026-10-17): un numero del lenguaje es un entero o un flotante
;;;; de doble precision, como en una hoja de calculo y en JavaScript. Nunca
;;;; un racional exacto de Common Lisp ni un flotante simple.
;;;;
;;;; Antes no se habia decidido, porque el corpus no divide nunca y solo usa
;;;; enteros. En cuanto una descripcion divide, el evaluador devolvia 157/3,
;;;; que el texto plano escribia tal cual y que rompia el oraculo JSON; y un
;;;; 1.2 escrito en los datos se leia como flotante simple, de modo que 3 por
;;;; 1.2 daba 3.6000001. Ninguna de las dos cosas es lo que da una hoja de
;;;; calculo ni una pagina, que son el otro lado de la comparacion.
;;;;
;;;; Aqui viven tres cosas, y solo aqui:
;;;;
;;;;   NORMALIZAR-NUMERO   cualquier numero a entero o doble. Se aplica al
;;;;                       cargar los datos, al compilar los literales y al
;;;;                       dividir.
;;;;   TEXTO-DE-NUMERO     la regla de PRESENTACION: hasta 10 cifras
;;;;                       significativas, sin ceros a la derecha, sin punto
;;;;                       si es entero. La aplican el evaluador (y por tanto
;;;;                       el texto plano y las explicaciones de las marcas) y,
;;;;                       con su propia realizacion, la pagina y la hoja de
;;;;                       calculo.
;;;;   ESCRITURA-DE-NUMERO la representacion EXACTA, para escribir un numero
;;;;                       como literal dentro de una formula, de un programa o
;;;;                       de un JSON: sin perder cifras y sin el sufijo "d0"
;;;;                       que pone Common Lisp a un doble.
;;;;
;;;; Y, desde la fase 2 (hueco C6), los decimales que declara un campo y el
;;;; operador REDONDEAR: REDONDEAR-A-DECIMALES, TEXTO-CON-DECIMALES y
;;;; TEXTO-DEL-CAMPO. Las dos redondean al mas cercano y, en el empate, se
;;;; alejan de cero, que es lo que hacen el formato de numero y ROUND de Excel
;;;; y de LibreOffice. Y redondean la escritura DECIMAL del numero, no el doble
;;;; binario: 2.675 es en binario 2.67499999..., y un redondeo ingenuo daria
;;;; 2.67 donde la hoja de calculo da 2.68.

(in-package #:situacion.nucleo)

(defparameter +cifras-de-presentacion+ 10
  "Cuantas cifras significativas se ensenan de un numero no entero.")

(defun normalizar-numero (valor)
  "VALOR como entero o como doble. Lo que no es un numero se deja igual.

   Un flotante simple se convierte por su representacion escrita, no por su
   valor binario: el 1.2 que alguien escribio en los datos tiene que ser el
   doble 1.2, no 1.2000000476837158, que es lo que da COERCE."
  (typecase valor
    (integer valor)
    (double-float valor)
    (ratio (coerce valor 'double-float))
    (float (let ((*read-default-float-format* 'double-float))
             (let ((leido (read-from-string
                           (let ((*read-default-float-format* (type-of valor)))
                             (prin1-to-string valor)))))
               (if (realp leido) (coerce leido 'double-float)
                   (coerce valor 'double-float)))))
    (t valor)))

(defun entero-si-se-puede (x)
  "X como entero si es un doble sin parte decimal y de magnitud razonable."
  (if (and (floatp x) (< (abs x) 1d15) (= x (ftruncate x)))
      (truncate x)
      x))

(defun escritura-de-numero (valor)
  "La representacion exacta de VALOR, apta como literal en una formula de
   hoja de calculo, en JavaScript y en JSON."
  (let ((x (normalizar-numero valor)))
    (cond ((integerp x) (format nil "~d" x))
          (t (let ((y (entero-si-se-puede x)))
               (if (integerp y)
                   (format nil "~d" y)
                   (let ((*read-default-float-format* 'double-float))
                     ;; PRIN1 de un doble con el formato por defecto en doble
                     ;; no lleva sufijo, y su exponente, si lo hay, sale con
                     ;; "e", que las tres sintaxis aceptan.
                     (string-downcase (prin1-to-string y)))))))))

(defun redondear-a-cifras (x cifras)
  "X redondeado a CIFRAS cifras significativas, como doble."
  (if (zerop x)
      0d0
      (let* ((magnitud (floor (log (abs x) 10)))
             (escala (expt 10 (- cifras 1 magnitud))))
        (coerce (/ (round (* (rational x) escala)) escala) 'double-float))))

(defun texto-de-numero (valor)
  "VALOR escrito para que lo lea una persona: hasta 10 cifras significativas,
   sin ceros a la derecha, sin punto si es entero.

   52.333333333333336 se escribe 52.33333333; 3.6000000000000001, 3.6; 3.0,
   3. Es la misma regla que aplican la pagina (funcion T) y la hoja de
   calculo cuando un numero entra en un texto."
  (let ((x (normalizar-numero valor)))
    (if (integerp x)
        (format nil "~d" x)
        (let ((y (entero-si-se-puede
                  (coerce (redondear-a-cifras x +cifras-de-presentacion+)
                          'double-float))))
          (if (integerp y)
              (format nil "~d" y)
              (escritura-de-numero y))))))

;;; ---------------------------------------------------------------------
;;; Decimales y redondeo (fase 2, hueco C6)
;;; ---------------------------------------------------------------------

(defun decimal-exacto (x)
  "El racional exacto que escribe X en decimal: 2.675 es 2675/1000, no el
   doble binario mas cercano. Se parte de la escritura mas corta que vuelve
   al mismo doble, que es la que da PRIN1."
  (if (rationalp x)
      x
      (let* ((texto (let ((*read-default-float-format* 'double-float))
                      (string-downcase (prin1-to-string (coerce x 'double-float)))))
             (e (position #\e texto))
             (mantisa (subseq texto 0 e))
             (exponente (if e (parse-integer texto :start (1+ e)) 0))
             (signo (if (char= (char mantisa 0) #\-) -1 1))
             (sin-signo (string-left-trim "-" mantisa))
             (punto (position #\. sin-signo))
             (entera (subseq sin-signo 0 punto))
             (fraccion (if punto (subseq sin-signo (1+ punto)) "")))
        (* signo
           (parse-integer (concatenate 'string entera fraccion))
           (expt 10 (- exponente (length fraccion)))))))

(defun redondeo-exacto (x n)
  "X redondeado a N decimales como racional exacto, con el empate
   alejandose de cero."
  (let* ((r (decimal-exacto x))
         (escala (expt 10 n)))
    (/ (* (signum r) (floor (+ (* (abs r) escala) 1/2))) escala)))

(defun redondear-a-decimales (valor n)
  "VALOR redondeado a N decimales: un entero si N es 0, un doble si no. Un
   vacio sigue siendo vacio; cualquier otro valor se lee como numero, igual
   que en la aritmetica."
  (if (vacio-p valor)
      nil
      (let ((r (redondeo-exacto (normalizar-numero (como-numero valor)) n)))
        (if (zerop n) r (normalizar-numero r)))))

(defun texto-con-decimales (valor n)
  "VALOR escrito con exactamente N decimales: 2.5 con 2 es \"2.50\". Lo que
   no es un numero se escribe como siempre. Un resultado que redondea a cero
   se escribe sin signo."
  (let ((x (normalizar-numero valor)))
    (if (not (realp x))
        (como-texto valor)
        (let* ((r (redondeo-exacto x n))
               (escala (expt 10 n))
               (entero (abs (* r escala))))
          (multiple-value-bind (parte-entera fraccion) (floor entero escala)
            (format nil "~:[~;-~]~d~:[~;.~v,'0d~]"
                    (minusp r) parte-entera (plusp n) n fraccion))))))

(defun texto-del-campo (campo valor)
  "Como se escribe VALOR en una celda de CAMPO: con los decimales que el
   campo declara, o con la regla general si no declara ninguno. Lo usan las
   tres arquitecturas y los oraculos, asi que una celda se lee igual en
   todas."
  (if (and (decimales campo) (realp (normalizar-numero valor)))
      (texto-con-decimales valor (decimales campo))
      (como-texto valor)))
