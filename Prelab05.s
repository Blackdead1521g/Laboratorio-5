 /* Archivo: Lab02.s
 * Dispositivo: PIC16F887
 * Autor: Kevin Alarcón
 * Compilador: pic-as (v2.30), MPLABX V6.05
 * 
 * 
 * Programa: Presionar RB6 o RB7 para incrementar o decrementar usando interrupciones
 * Hardware: Push en RB6 y RB7, leds en puerto A
 * 
 * Creado: 20 de feb, 2023
 * Última modificación: 20 de feb, 2023
 */
    
    PROCESSOR 16F887
    #include <xc.inc>
    
    ;configuración wor 1
    CONFIG FOSC=INTRC_NOCLKOUT //Oscilador Interno sin salidas
    CONFIG WDTE=OFF //WDT disabled (reinicio repetitivo del pic)
    CONFIG PWRTE=OFF //PWRT enabled (espera de 72ms al iniciar)
    CONFIG MCLRE=OFF //El pin de MCLR se utiliza como I/0
    CONFIG CP =OFF //Sin protección de código
    CONFIG CPD=OFF //Sin protección de datos
    
    CONFIG BOREN=OFF //Sin reinicio cúando el voltaje de alimentación baja de 4V
    CONFIG IESO=OFF //Reinicio sin cambio de reloj de interno a externo
    CONFIG FCMEN=OFF //Cambio de reloj externo a interno en caso de fallo
    CONFIG LVP=OFF //Programación en bajo voltaje permitida
    
    ;configuración word 2
    CONFIG WRT=OFF //Protección de autoescritura por el programa desactivada
    CONFIG BOR4V=BOR40V //Programación abajo de 4V, (BOR21V=2 . 1V)
    
    UP EQU 6
    DOWN EQU 7
    ;--------------------------MACROS------------------------------
    restart_TMR0 macro
	banksel TMR0 ;Nos ubicamos en el banco donde está TMR0
	movlw 246 ;Cargamos al acumulador el valor que se le pondrá al TMR0
	movwf TMR0 ;Cargamos el valor N calculado para un desborde de 1000mS
	bcf T0IF ;Colocamos en cero la bandera del TMR0
    endm
    
    PSECT udata_bank0; common memory
	count: DS 1 ;1 byte
	banderas: DS 1 ;1 bytes
	display_var: DS 2
	display1: DS 1 ;1 bytes
	display2: DS 1 ;1 bytes
	nibble: DS 2 ;2 byte
 
    PSECT udata_shr
 	W_TEMP: DS 1 ;1 byte
    	STATUS_TEMP: DS 1 ;1 byte
    
    ;--------------------------vector reset------------------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h ;posición 0000h para el reset
    resetVec:
	PAGESEL main
	goto main
    ;--------------------------Vector interrupción-------------------
    PSECT intVECT, class=CODE, abs, delta=2
    ORG 0004h
    push: 
	movwf W_TEMP ;Movemos lo que hay en el acumulador al registro
	swapf STATUS, W ;Intercambiamos los bits del registro STATUS y lo metemos al acumulador
	movwf STATUS_TEMP ;Movemos lo que hay en el acumulador al registro
    isr:
	btfsc RBIF ;Verificamos si alguno de los puertos de B cambiaron de estado
	call int_iocb ;Si, sí cambió de estado, llamamos a nuestra función 
	btfsc T0IF ;Verificamos si la bandera del TMR0 está encendida
	call int_t0 ;Si, Sí está encendida la bandera del TMR0 llamamos a nuestra función
    pop:
	swapf STATUS_TEMP, W ;Intercambiamos los bits del registro STATUS y lo metemos al acumulador
	movwf STATUS ;Movemos lo que hay en el acumulador al registro
	swapf W_TEMP, F ;Intercambiamos los bits del registro y lo metemos al mismo registro
	swapf W_TEMP, W ;Intercambiamos los bits del registro y lo metemos al acumulador
	retfie ;Carga el PC con el valor que se encuentra en la parte superior de la pila, asegurando así la vuelta de la interrupción
    
    PSECT code, delta=2, abs
    ORG 100h  ;posición para el código
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
	
    ;----------------------configuración----------------
    main:
	call config_io ;Llamamos a nuestra subrutina config_io para configurar los pines antes de ejecutar el código
	call config_reloj ;Llamamos a nuestra subrutina config_reloj para configurar la frecuencia del reloj antes de ejecutar el código
	call config_TMR0 ;Llamamos a nuestra función para configurar el TMR0
	call config_iocb ;Llamamos a nuestra función que habilita las interrupciones en el puerto B
	call config_int_enable ;Llamamos a nuestra función que habilita las interrupciones en general
	banksel PORTD ;Se busca el banco en el que está PORTA
	
    
    ;-----------------------loop principal---------------
    loop:
	call separar_nibbles
	call preparar_display
	goto loop ; loop forever
	
    ;----------------------Sub rutinas------------------
    separar_nibbles:
	movf count, W
	andlw 00001111B
	movwf nibble
	swapf count, W
	andlw 00001111B
	movwf nibble+1
	return
    
    preparar_display:
	movf nibble, W
	call table
	movwf display1
	movf nibble+1, W
	call table
	movwf display2
	return 
    
    config_io: ;Función para configurar los puertos de entrada/salida
	bsf STATUS, 5 ;banco 11
	bsf STATUS, 6 ;Nos dirigimos al banco 3 porque ahí se encuentran las instrucciones ANSEL y ANSELH
	clrf ANSEL ;pines digitales
	clrf ANSELH
    
	bsf STATUS, 5 ;banco 01
	bcf STATUS, 6 ;Nos dirigimos al banco 1 porque ahí se encuentran lo configuración de los puertos
	
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
	
	;Nos dirigimos al banco 0 en donde se encuentran los puertos y procedemos a limpiar cada puerto después de cada reinicio
	bcf STATUS, 5 ;banco00
	bcf STATUS, 6 
	clrf banderas
	clrf count
	clrf nibble
	clrf PORTA
	clrf PORTD
	clrf PORTC
	clrf PORTE
	return ;Retorna a donde fue llamada esta función
	
    config_reloj:
	banksel OSCCON ;Nos posicionamos en el banco en donde esté el registro OSCCON para configurar el reloj
	;Esta configuración permitirá poner el oscilador a 1 MHz
	bsf IRCF2 ;OSCCON 6 configuramos el bit 2 del IRCF como 1
	bcf IRCF1 ;OSCCON 5 configuramos el bit 1 del IRCF como 0
	bcf IRCF0 ;OSCCON 4 configuramos el bit 0 del IRCF como 0
	bsf SCS ;reloj interno 
	return ;Retorna a donde fue llamada esta función
	
    config_TMR0:
	banksel OPTION_REG
	bcf OPTION_REG, 5 ;Seleccionamos TMR0 como temporizador
	bcf OPTION_REG, 3 ;Asignamos PRESCALER a TMR0
	bsf OPTION_REG, 2 
	bsf OPTION_REG, 1
	bsf OPTION_REG, 0 ;Prescaler de 256 con configuración 111
	restart_TMR0 ;Reiniciamos el TMR0 con nuestra función
	return ;Retorna a donde fue llamada esta función

    config_int_enable:
	bsf T0IE ;INTCON ;Habilitamos la interrupción del TMR0
	bsf T0IF ;INTCON ;Ponemos en cero la bandera del TMR0
	bsf GIE ;INTCON ;Habilitamos las interrupciones en general
	bsf RBIE ;INTCON ;Habilitamos la interrupción del cambio en el puerto B
	bcf RBIF ;INTCON ;Ponemos en cero el cambio de estado para que se reinicie la verificación
	return

    config_iocb:
	banksel TRISB ;Nos ubicamos en el banco del TRISB
	bsf IOCB, UP ;Habilitamos la interrupción al cambiar el estado de RB6
	bsf IOCB, DOWN ;Habilitamos la interrupción al cambiar el estado de RB7
	
	banksel PORTB 
	movf PORTB, W ;al leer termina la condición de mismatch
	bcf RBIF ;Ponemos en cero el cambio de estado para que se reinicie la verificación
	return ;Retornamos de nuestra función
	
    int_t0:
	restart_TMR0 ;Reiniciamos el TMR0
	//separar_nibbles:
	/*movf count, W
	andlw 00001111B
	movwf nibble
	swapf count, W
	andlw 00001111B
	movwf nibble+1
	return
    
   // preparar_display:
	movf nibble, W
	call table
	movwf display1
	movf nibble+1, W
	call table
	movwf display2
	return */
	
	clrf PORTE
	btfsc banderas, 0
	goto display_2
	    
    display_1:
	movf display1, W
	movwf PORTC
	bsf PORTE, 0
	goto toggle_b0
	
    display_2:
	movf display2, W
	movwf PORTC
	bsf PORTE, 1

    toggle_b0:
	movlw 0x01
	xorwf banderas, F
	return 
	
    int_iocb:
	banksel PORTB ;Nos ubicamos en el banco del purto B
	btfss PORTB, UP ;Al estar en pullup normalmente el boton está en 1, así que verificamos si está en 1 (desoprimido) o en 0 (oprimido
		;el bit 6 del puerto B
	incf PORTA ;Si está en 0 (oprimido) incrementamos el puerto E
	movf PORTA, W
	movwf count
	btfss PORTB, DOWN  ;Al estar en pullup normalmente el boton está en 1, así que verificamos si está en 1 (desoprimido) o en 0 (oprimido
		   ;el bit 7 del puerto B
	decf PORTA ;Si está en 0 (oprimido) decrementamos el puerto E
	movf PORTA, W
	movwf count
	bcf RBIF ;Ponemos en cero el cambio de estado para que se reinicie la verificación
	return ;Retornamos de nuestra función
    END



