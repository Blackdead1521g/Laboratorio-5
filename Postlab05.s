 /* Archivo: Postlab05.s
 * Dispositivo: PIC16F887
 * Autor: Kevin Alarc�n
 * Compilador: pic-as (v2.30), MPLABX V6.05
 * 
 * 
 * Programa: Presionar RB6 o RB7 para incrementar o decrementar un contador y mostrarlo en tres displays multiplexados en unidades, decenas y centnas
 * Hardware: Push en RB6 y RB7, displays en puerto C
 * 
 * Creado: 20 de feb, 2023
 * �ltima modificaci�n: 23 de feb, 2023
 */
    
    PROCESSOR 16F887
    #include <xc.inc>
    
    ;configuraci�n wor 1
    CONFIG FOSC=INTRC_NOCLKOUT //Oscilador Interno sin salidas
    CONFIG WDTE=OFF //WDT disabled (reinicio repetitivo del pic)
    CONFIG PWRTE=OFF //PWRT enabled (espera de 72ms al iniciar)
    CONFIG MCLRE=OFF //El pin de MCLR se utiliza como I/0
    CONFIG CP =OFF //Sin protecci�n de c�digo
    CONFIG CPD=OFF //Sin protecci�n de datos
    
    CONFIG BOREN=OFF //Sin reinicio c�ando el voltaje de alimentaci�n baja de 4V
    CONFIG IESO=OFF //Reinicio sin cambio de reloj de interno a externo
    CONFIG FCMEN=OFF //Cambio de reloj externo a interno en caso de fallo
    CONFIG LVP=OFF //Programaci�n en bajo voltaje permitida
    
    ;configuraci�n word 2
    CONFIG WRT=OFF //Protecci�n de autoescritura por el programa desactivada
    CONFIG BOR4V=BOR40V //Programaci�n abajo de 4V, (BOR21V=2 . 1V)
    
    UP EQU 6
    DOWN EQU 7
    ;--------------------------MACROS------------------------------
    restart_TMR0 macro
	banksel TMR0 ;Nos ubicamos en el banco donde est� TMR0
	movlw 246 ;Cargamos al acumulador el valor que se le pondr� al TMR0
	movwf TMR0 ;Cargamos el valor N calculado para un desborde de 1000mS
	bcf T0IF ;Colocamos en cero la bandera del TMR0
    endm
    
    PSECT udata_bank0; common memory
	count: DS 1 ;1 byte
	banderas: DS 1 ;1 bytes
	display: DS 3 ;1 bytes
	nibble: DS 2 ;2 bytes
	unidades: DS 2 ;2 bytes
	decenas: DS 2 ;2 bytes
	centenas: DS 2 ;2 bytes
	
 
    PSECT udata_shr
 	W_TEMP: DS 1 ;1 byte
    	STATUS_TEMP: DS 1 ;1 byte
    
    ;--------------------------vector reset------------------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h ;posici�n 0000h para el reset
    resetVec:
	PAGESEL main
	goto main
    ;--------------------------Vector interrupci�n-------------------
    PSECT intVECT, class=CODE, abs, delta=2
    ORG 0004h
    push: 
	movwf W_TEMP ;Movemos lo que hay en el acumulador al registro
	swapf STATUS, W ;Intercambiamos los bits del registro STATUS y lo metemos al acumulador
	movwf STATUS_TEMP ;Movemos lo que hay en el acumulador al registro
    isr:
	btfsc RBIF ;Verificamos si alguno de los puertos de B cambiaron de estado
	call int_iocb ;Si, s� cambi� de estado, llamamos a nuestra funci�n 
	btfsc T0IF ;Verificamos si la bandera del TMR0 est� encendida
	call int_t0 ;Si, S� est� encendida la bandera del TMR0 llamamos a nuestra funci�n
    pop:
	swapf STATUS_TEMP, W ;Intercambiamos los bits del registro STATUS y lo metemos al acumulador
	movwf STATUS ;Movemos lo que hay en el acumulador al registro
	swapf W_TEMP, F ;Intercambiamos los bits del registro y lo metemos al mismo registro
	swapf W_TEMP, W ;Intercambiamos los bits del registro y lo metemos al acumulador
	retfie ;Carga el PC con el valor que se encuentra en la parte superior de la pila, asegurando as� la vuelta de la interrupci�n
    
    PSECT code, delta=2, abs
    ORG 100h  ;posici�n para el c�digo
    table:
	clrf PCLATH
	bsf PCLATH, 0 ;PCLATH en 01
	andlw 0X0F ;
	addwf PCL ;PC = PCLATH + PCL | Sumamos W al PCL para seleccionar una dato de la tabla
	retlw 00111111B ;0
	retlw 00000110B;1
	retlw 01011011B ;2
	retlw 01001111B ;3
	retlw 01100110B ;4
	retlw 01101101B ;5
	retlw 01111101B ;6
	retlw 00000111B ;7
	retlw 01111111B ;8
	retlw 01101111B ;9
	retlw 01110111B ;A
	retlw 01111100B ;B
	retlw 00111001B ;C
	retlw 01011110B ;D
	retlw 01111001B ;E
	retlw 01110001B ;F
	
    ;----------------------configuraci�n----------------
    main:
	call config_io ;Llamamos a nuestra subrutina config_io para configurar los pines antes de ejecutar el c�digo
	call config_reloj ;Llamamos a nuestra subrutina config_reloj para configurar la frecuencia del reloj antes de ejecutar el c�digo
	call config_TMR0 ;Llamamos a nuestra funci�n para configurar el TMR0
	call config_iocb ;Llamamos a nuestra funci�n que habilita las interrupciones en el puerto B
	call config_int_enable ;Llamamos a nuestra funci�n que habilita las interrupciones en general
	banksel PORTA ;Se busca el banco en el que est� PORTA
	
    
    ;-----------------------loop principal---------------
    loop:
	movf PORTA, W ;Metemos lo que hay en el puerto A al acumulador 
	movwf count ;Movemos el valor del acumulador a nuestra variable count
	
	call preparar_display ;Llamamos a nuestra funci�n que le asigna cada valor a su respectivo display
	
	;Limpiamos las variables que utilizaremos para guardar los valores del contador en cada loop
	clrf unidades 
	clrf decenas
	clrf centenas
	
	call conv_centenas ;Llamamos a nuestra funci�n que convierte el valor a centenas
	call conv_decenas ;Llamamos a nuestra funci�n que convierte el valor a decenas
	call conv_unidades ;Llamamos a nuestra funci�n que convierte el valor a unidades
	goto loop ; loop forever
	
    ;----------------------Sub rutinas------------------
    config_iocb: ;Funci�n para habilitar las interrupciones en el puerto B
	banksel TRISB ;Nos ubicamos en el banco del TRISB
	bsf IOCB, UP ;Habilitamos la interrupci�n al cambiar el estado de RB6
	bsf IOCB, DOWN ;Habilitamos la interrupci�n al cambiar el estado de RB7
	
	banksel PORTB 
	movf PORTB, W ;al leer termina la condici�n de mismatch
	bcf RBIF ;Ponemos en cero el cambio de estado para que se reinicie la verificaci�n
	return ;Retornamos de nuestra funci�n
	
    config_io: ;Funci�n para configurar los puertos de entrada/salida
	bsf STATUS, 5 ;banco 11
	bsf STATUS, 6 ;Nos dirigimos al banco 3 porque ah� se encuentran las instrucciones ANSEL y ANSELH
	clrf ANSEL ;pines digitales
	clrf ANSELH
    
	bsf STATUS, 5 ;banco 01
	bcf STATUS, 6 ;Nos dirigimos al banco 1 porque ah� se encuentran lo configuraci�n de los puertos
	
	;Configuramos los bits que usaremos como entradas del PORTB
	bsf TRISB, UP
	bsf TRISB, DOWN
	bsf TRISE, 0
	bsf TRISE, 1
	
	;Configuramos las salidas
	clrf TRISA
	clrf TRISD
	clrf TRISC
	clrf TRISE
	
	bcf OPTION_REG, 7 ;Habilitamos Pull ups
	bsf WPUB, UP
	bsf WPUB, DOWN
	
	;Nos dirigimos al banco 0 en donde se encuentran los puertos y procedemos a limpiar cada puerto despu�s de cada reinicio
	bcf STATUS, 5 ;banco00
	bcf STATUS, 6 
	clrf banderas
	clrf count
	clrf PORTA
	clrf PORTD
	clrf PORTC
	clrf PORTE
	return ;Retorna a donde fue llamada esta funci�n
	
    conv_centenas: ;Esta funci�n nos sirve para extraer las centenas de nuestro contador 
	movlw 100 ;Movemos 100 al acumulador
	subwf count, F ;Le restamos a nuestra variable de contador los 100 del acumulador y lo guardamos en el registro
	incf centenas ;Incrementamos centenas
	btfsc STATUS, 0 ;Revisamos si queda un acarreo despu�s de la resta
	goto $-4 ;Si queda alg�n acarreo del bit mas significativo volvemos a repetir el procedimiento anterior
	decf centenas ;Si no queda ning�n acarreo, esto significa que pasamos a un valor negativo por lo tanto le decrementamos el valor
		      ; a que le hab�amos incrementado a centenas inicialmente
	movlw 100 ;Movemos 100 al acumulador 
	addwf count, F ;Le ingresamos dicho n�mero a nuestra variable contador por si en dado caso queda negativa nuestra variable
	return

    conv_decenas: ;Esta funci�n nos sirve para extraer las decenas de nuestro contador 
	movlw 10 ;Movemos 10 al acumulador
	subwf count, F ;Le restamos a nuestra variable de contador los 10 del acumulador y lo guardamos en el registro
	incf decenas ;Incrementamos decenas
	btfsc STATUS, 0 ;Revisamos si queda un acarreo despu�s de la resta
	goto $-4 ;Si queda alg�n acarreo del bit mas significativo volvemos a repetir el procedimiento anterior
	decf decenas ;Si no queda ning�n acarreo, esto significa que pasamos a un valor negativo por lo tanto le decrementamos el valor
		     ; a que le hab�amos incrementado a decenas inicialmente
	movlw 10 ;Movemos 10 al acumulador
	addwf count, F  ;Le ingresamos dicho n�mero a nuestra variable contador por si en dado caso queda negativa nuestra variable
	return
	
    conv_unidades: ;Esta funci�n nos sirve para extraer las unidades de nuestro contador
	movlw 1 ;Movemos 1 al acumulador
	subwf count, F ;Le restamos a nuestra variable de contador el 1 del acumulador y lo guardamos en el registro
	incf unidades ;Incrementamos unidades
	btfsc STATUS, 0 ;Revisamos si queda un acarreo despu�s de la resta
	goto $-4 ;Si queda alg�n acarreo del bit mas significativo volvemos a repetir el procedimiento anterior
	decf unidades ;Si no queda ning�n acarreo, esto significa que pasamos a un valor negativo por lo tanto le decrementamos el valor
		      ; a que le hab�amos incrementado a unidades inicialmente
	movlw 1 ;Movemos 1 al acumulador
	addwf count, F ;Le ingresamos dicho n�mero a nuestra variable contador por si en dado caso queda negativa nuestra variable
	return
	
    preparar_display: ;Esta funci�n configura cada valor en su respectivo display
	movf decenas, W ;Movemos decenas al acumulador
	call table ;Mandamos a llamar a la tabla y extraemos un valor
	movwf display ;Movemos el valor extraido a nuestra variable display
	
	movf centenas, W ;Movemos centenas al acumulador
	call table ;Mandamos a llamar a la tabla y extraemos un valor
	movwf display+1 ;Movemos el valor extraido a nuestra variable display+1
	
	movf unidades, W ;Movemos unidades al acumulador
	call table ;Mandamos a llamar a la tabla y extraemos un valor
	movwf display+2 ;Movemos el valor extraido a nuestra variable display+2
	return 
	
    config_reloj:
	banksel OSCCON ;Nos posicionamos en el banco en donde est� el registro OSCCON para configurar el reloj
	;Esta configuraci�n permitir� poner el oscilador a 1 MHz
	bsf IRCF2 ;OSCCON 6 configuramos el bit 2 del IRCF como 1
	bcf IRCF1 ;OSCCON 5 configuramos el bit 1 del IRCF como 0
	bcf IRCF0 ;OSCCON 4 configuramos el bit 0 del IRCF como 0
	bsf SCS ;reloj interno 
	return ;Retorna a donde fue llamada esta funci�n
	
    config_TMR0:
	banksel OPTION_REG
	bcf OPTION_REG, 5 ;Seleccionamos TMR0 como temporizador
	bcf OPTION_REG, 3 ;Asignamos PRESCALER a TMR0
	bsf OPTION_REG, 2 
	bsf OPTION_REG, 1
	bsf OPTION_REG, 0 ;Prescaler de 256 con configuraci�n 111
	restart_TMR0 ;Reiniciamos el TMR0 con nuestra funci�n
	return ;Retorna a donde fue llamada esta funci�n

    config_int_enable:
	bsf T0IE ;INTCON ;Habilitamos la interrupci�n del TMR0
	bsf T0IF ;INTCON ;Ponemos en cero la bandera del TMR0
	bsf GIE ;INTCON ;Habilitamos las interrupciones en general
	bsf RBIE ;INTCON ;Habilitamos la interrupci�n del cambio en el puerto B
	bcf RBIF ;INTCON ;Ponemos en cero el cambio de estado para que se reinicie la verificaci�n
	return
	
    int_t0:
	call display_selections ;Llamos a nuestra funci�n de selecci�n de display
	restart_TMR0 ;Reiniciamos el TMR0
	return

    display_selections:
	;Limpiamos los bits utilizador el puerto E
	bcf PORTE, 0
	bcf PORTE, 1
	bcf PORTE, 2
	
	btfsc banderas, 1 ;Verificamos si el bit 1 de banderas se activa
	goto display_2 ;Si se activa saltamos a la funci�n display_2
	btfsc banderas, 0 ;Verificamos si el bit 0 de banderas se activa
	goto display_0 ;Si se activa saltamos a la funci�n display_0
	goto display_1 ;Si no se activa saltamos a la funci�n display_1
	
    display_0:
	movf display, W ;Movemos nuestra variable display al acumulador
	movwf PORTC ;Movemos este valor al puerto C
	bsf PORTE, 1 ;Activamos el bit 1 que activar� su respectivo display
	bcf banderas, 0 ;Ponemos en 0 el bit 0 de banderas
	bsf banderas, 1 ;Ponemos en 1 el bit 1 de banderas
	return
	
    display_1:
	movf display+1, W ;Movemos nuestra variable display+1 al acumulador
	movwf PORTC ;Movemos este valor al puerto C
	bsf PORTE, 0 ;Activamos el bit 0 que activar� su respectivo display
	bsf banderas, 0 ;Ponemos en 1 el bit 0 de banderas
	return
	
	
    display_2:
	movf display+2, W ;Movemos nuestra variable display+2 al acumulador
	movwf PORTC ;Movemos este valor al puerto C
	bsf PORTE, 2 ;Activamos el bit 2 que activar� su respectivo display
	bcf banderas, 0 ;Ponemos en 0 el bit 0 de banderas
	bcf banderas, 1 ;Ponemos en 0 el bit 1 de banderas
	return
    
    int_iocb:
	banksel PORTB ;Nos ubicamos en el banco del purto B
	btfss PORTB, UP ;Al estar en pullup normalmente el boton est� en 1, as� que verificamos si est� en 1 (desoprimido) o en 0 (oprimido
		;el bit 6 del puerto B
	incf PORTA ;Si est� en 0 (oprimido) incrementamos el puerto E
	
	btfss PORTB, DOWN  ;Al estar en pullup normalmente el boton est� en 1, as� que verificamos si est� en 1 (desoprimido) o en 0 (oprimido
		   ;el bit 7 del puerto B
	decf PORTA ;Si est� en 0 (oprimido) decrementamos el puerto E
	bcf RBIF ;Ponemos en cero el cambio de estado para que se reinicie la verificaci�n
	return ;Retornamos de nuestra funci�n
    END