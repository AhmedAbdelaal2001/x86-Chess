.286    ;For 8086 microprocessor assembly instructions

;-------------------------------------------------------------------------------------------------------------------------------------------------

.model huge ;To be adjusted (maybe), setting the model to huge for now just to be safe :)

;-------------------------------------------------------------------------------------------------------------------------------------------------

.stack 64

;-------------------------------------------------------------------------------------------------------------------------------------------------

.data

    ;---------------------------------------------------------------------------------------------------------------------------------------------
    ;PATH CONTROL AND ERROR MESSAGE:
    ;---------------------------------------------------------------------------------------------------------------------------------------------
    
    ;Name of the folder containing images of all pieces, will be used to change directory at the start of the main proc.
    pieces_wd   db  "pieces", 0

    ;Message to be displayed if a file fails to open.
    error_msg   db  "Error! Could not open bitmap files.$"

    ;---------------------------------------------------------------------------------------------------------------------------------------------
    ;VARIABLES USED IN THE MAIN MENU:
    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Three command messages to be displayed at the main menu
    cmd1    db  'To start chatting press F1', '$'

    cmd2    db  'To start the game press F2', '$'

    cmd3    db  'To end the program press ESC', '$'

    ;---------------------------------------------------------------------------------------------------------------------------------------------
    ;VARIABLES USED IN THE CHAT MENU:
    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Chat screen title
    chat_title  db  'Chat', '$'

    ;Name of the other player (to be modified in phase 2)
    temp_name   db  'Miro', '$'

    ;Dummy text to be displayed
    dummy       db  'This window is to be further developed in phase 2, thanks for checking in.', '$'

    dummy2      db  'Press F3 to exit', '$'

    ;---------------------------------------------------------------------------------------------------------------------------------------------
    ;VARIABLES USED FOR PREPARING AND DRAWING THE BOARD:
    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;An array that will store the current state of the board, each element of the array corresponds to a cell on the board.
    board                   db  64d dup(0)

    selectedPiecePos        dw  ?

    possibleMoves_DI        dw  8 Dup(7 Dup(-1))
    possibleMoves_SI        dw  8 Dup(7 Dup(-1))

    ;           ---------------------------------------------------------------------------> Possible moves in that direction
    ;           |   Up          (possibleMoves_DI[0],possibleMoves_SI[0]) .  .  .  .  .  .  .  .  .  .  .
    ;           |   Up-Right                             .
    ;           |   Right                                .
    ;           |   Down-Right                           .
    ;           |   Down                                 .
    ;           |   Down-Left                            .
    ;           |   Left                                 .
    ;           |   Up-Left     (possibleMoves_DI[49],possibleMoves_SI[49])
    ;           v
    ;       Directions

    ; Keeps track of the possible move that the player is currently selecting and are used to write the moves to memory in "recordMove"
    directionPtr            db  0d
    currMovePtr             db  0d

    ; the position (containing a piece) that the player is currently selecting
    currSelectedPos_SI      dw  ?
    currSelectedPos_DI      dw  ?

    ; Step unit (-1 for white & 1 for black)
    walker                  dw  ?

    ;The size of each cell on the chessboard.
    cell_size               dw  75d

    ;Horizontal margin is set to 4 cells
    margin_x                dw  4

    ;Vertical margin is set to 2 cells (This might be altered later, to clear some space for chatting).
    margin_y                dw  2

    ;Cells can have 2 colors: white and gray. The codes of those colors are stored here, and will be used when drawing the board.
    board_colors            db  31d, 28d

    ; Used for highlighting (hover effect)
    highlighted_cell_color  db  14d

    ;Stores the color of the cell being drawn at a specific iteration.
    temp_color              db  ?

    ;No. of loops that the delay function will execute
    delay_loops             dw  ?

    ;---------------------------------------------------------------------------------------------------------------------------------------------
    ;VARIABLES USED TO ACCESS AND DRAW CHESS PIECES:
    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Unique reference number that will be assigned to files when accessing them. This variable is used when calling interrupts to read from the bitmap files.
    file_handle         dw  0
    
    ;The number of bytes in each image.
    file_size           dw  5776d

    ;The dimensions of each image.
    file_width          dw  76d

    ;Reading a bitmap image will be done row by row (each row contains 76 bytes).
    ;Hence, a buffer of size 76 is used to store the temporary data being read.
    bitmap_buffer       db  5776d dup(?)
                      
    ;Temporary x-coordinate that will be used when loading a bitmap image to the board.
    x_temp              dw  ?

    ;Temporary y-coordinate that will be used when loading a bitmap image to the board.
    y_temp              dw  ?
    
    ;White Pieces

    ;Preparing file names
    whitePawn_file      db  'wPawn.bmp', 0
    whiteKnight_file    db  'wKnight.bmp', 0
    whiteBishop_file    db  'wBishop.bmp', 0
    whiteRook_file      db  'wRook.bmp', 0
    whiteQueen_file     db  'wQueen.bmp', 0
    whiteKing_file      db  'wKing.bmp', 0
	
    ;An array of pointers to every file name. Will be used to draw the pieces in a clean manner.
    white_pieces        dw  0
                        dw  whitePawn_file
                        dw  whiteKnight_file
                        dw  whiteBishop_file
                        dw  whiteRook_file
                        dw  whiteQueen_file
                        dw  whiteKing_file

    ;Black Pieces

    ;Preparing file names
    blackPawn_file      db  'bPawn.bmp', 0
    blackKnight_file    db  'bKnight.bmp', 0
    blackBishop_file    db  'bBishop.bmp', 0
    blackRook_file      db  'bRook.bmp', 0
    blackQueen_file     db  'bQueen.bmp', 0
    blackKing_file      db  'bKing.bmp', 0
    
    ;An array of pointers to every file name. Will be used to draw the pieces in a clean manner.
    black_pieces        dw  0
                        dw  blackPawn_file
                        dw  blackKnight_file
                        dw  blackBishop_file
                        dw  blackRook_file
                        dw  blackQueen_file
                        dw  blackKing_file

    ;---------------------------------------------------------------------------------------------------------------------------------------------

.code

    ;delays according to no. of 'delay_loops' in memory
    delay proc

        push    cx
        push    ax
        pushf
        mov     cx, delay_loops

        loop1:                
            mov ax, 65535d

            loop2:                
                dec     ax
                jnz     loop2
            
                loop    loop1

        popf
        pop     ax
        pop     cx

        ret

    delay endp

    ;Initializes the board pieces in memory.
    init_board proc

    ;Before placing any pieces on the board, initialize every location on the board to zero (i.e. empty the board)
        mov cx, 64d
        mov bx, offset board

        clear_board:          
            mov     [bx], byte ptr 0
            inc     bx
            loop    clear_board

    ;Places the pawns on their initial positions on board, 1 indicates a black pawn and -1 indicates a white pawn.
    ;Pawns fill the second and eighth rows.
        mov bx, offset board + 8
        mov cx, 8

        init_pawns:           
            mov     [bx], byte ptr 1
            add     bx, 40d
            mov     [bx], byte ptr -1
            sub     bx, 39d
            loop    init_pawns

    ;Places the knights on their initial positions on the board, 2 indicates a black knight and -2 indicates a white knight.
        mov bx, offset board + 1
        mov cx, 2

        init_knights:         
            mov     [bx], byte ptr 2
            add     bx, 56d
            mov     [bx], byte ptr -2
            sub     bx, 51d
            loop    init_knights

    ;Places the bishops on their initial positions on the board, 3 indicates a black bishop and -3 indicates a white bishop.
        mov bx, offset board + 2
        mov cx, 2

        init_bishops:         
            mov     [bx], byte ptr 3
            add     bx, 56d
            mov     [bx], byte ptr -3
            sub     bx, 53d
            loop    init_bishops

    ;Places the rooks on their initial positions on the board, 4 indicates a black rook and -4 indicates a white rook.
        mov bx, offset board
        mov cx, 2

        init_rooks:           
            mov     [bx], byte ptr 4
            add     bx, 56d
            mov     [bx], byte ptr -4
            sub     bx, 49d
            loop    init_rooks

    ;Places the queens on their initial positions on the board, 5 indicates a black queen and 6 indicates a white queen.
        mov bx, offset board + 3
        mov [bx], byte ptr 5
        add bx, 56d
        mov [bx], byte ptr -5

    ;Places the kings on their initial positions on the board, 6 indicates a black king and -6 indicates a white king.
        mov bx, offset board + 4
        mov [bx], byte ptr 6
        add bx, 56d
        mov [bx], byte ptr -6

        ret

    init_board endp
    ;Notice: magnitudes of the numeric values assigned to the pieces are ordered in the way that the white_pieces/black_pieces arrays are ordered.
    ;This is intentional, and will allow us to access the array positions easily when mapping the board to a drawing.

    ;--------------------------------------------------------------------------------------------------------------------------------------------

    ;Prepares the video mode for displaying the board. INT 10H with AX = 4F02H was used, which sets a VESA compliant video mode that allows for
    ;higher resolution when compared to the traditional 10H interrupts.
    init_video_mode proc

        mov ax, 4F02h
        mov bx, 107h    ;Resolution = 1280x1024, with a 256 color palette
        int 10h

        ret

    init_video_mode endp

    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Clears the entire screen (in this case, the dimensions of the screen are 1280x1024).
    ;The screen is set to the color stored in register AL.
    clear_screen proc

        mov ah, 0ch
        mov cx, 1280d

        loop_x_direction:     
            mov dx, 1024d

            loop_y_direction:     
                int   10h
                dec   dx
                jnz   loop_y_direction
                loop  loop_x_direction

        ret

    clear_screen endp

    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Checks whether or not there was an error when opening a bitmap file containing the image of any piece.
    ;All of the interrupts used to access files set the carry flag if an error occurs, and reset the carry flag if the file is opened successfully.
    ;Hence, checking the carry flag is sufficient to detect errors.
    check_file_error proc

        jc  error_handling

        ret

        error_handling:       
            mov ah, 9
            mov dx, offset error_msg
            int 21h
            mov ax, 4c00h
            int   21h

    check_file_error endp

    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Gets the file handle of the bitmap file we wish to access
    get_file_handle proc

        mov     ax, 3d00h
        int     21h
        call    check_file_error
        mov     [file_handle], ax

        ret

    get_file_handle endp

    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Moves file pointer to the beginning of the file (Read the documentation of the interrupt INT 21H, AH=42H "Seek File").
    go_to_file_start proc

        mov     ax, 4200h
        mov     bx, file_handle
        mov     cx, 0
        mov     dx, 0
        int     21h
        call    check_file_error

        ret

    go_to_file_start endp

    ;---------------------------------------------------------------------------------------------------------------------------------------------

    ;Every bitmap file contains a header block that is used to identify the file. We wish to bypass this block, so we use this procedure.
    ;We read the first 14 bytes of the header to extract information about the starting point of the image, then we go to that starting point.
    pass_file_header proc

        call    go_to_file_start
        mov     ax, 3f00h
        mov     cx, 14d
        mov     dx, offset bitmap_buffer
        int     21h

    ;Moves file pointer to the beginning of the data we wish to read. Bytes 10d and 12d in the header contain the needed information to position
    ;the file pointer at the starting point of the actual image.
        mov     bx, offset bitmap_buffer
        mov     dx, [bx + 10d]
        mov     cx, [bx + 12d]
        mov     ax, 4200h
        mov     bx, [file_handle]
        int     21h
        call    check_file_error

    pass_file_header endp

    ;----------------------------------------------------------------------------------------------------------------------------------------------

    ;loads the image of a piece, with its picture stored as a bitmap file.
    ;The image will be placed at the cell with row number stored in DI and column number stored in SI.
    ;Note: rows/columns range from 0 to 7, since the chess board has 8 rows and 8 columns.
    load_piece proc

    ;Get the actual position of the top left corner of the cell we wish to draw at, and store the coordinates in the x_temp and y_temp variables.
        mov ax, si
        mul cell_size
        mov x_temp, ax

        mov ax, di
        mul cell_size
        mov y_temp, ax
                
    ;Load the image into the bitmap_buffer.            
        mov bx, file_handle
        mov ah, 3fh
        mov cx, file_size
        mov dx, offset bitmap_buffer
        int 21h
        mov bx, offset bitmap_buffer
        add bx, 75d

    ;Nested loops which print the bitmap image pixel by pixel
        mov si, file_width
        dec si

        loop_y_bitmap:        
            mov di, file_width
            dec di

            loop_x_bitmap:

    ;Load the color of the current pixel to AL, since AL stored the color when drawing a pixel using INT 10H
                mov     al, byte ptr [bx]
                cmp     al, 0ffh            ;Do not draw any white pixels, to preserve the background color of the board.
                         
                je      continue_bitmap_loop
                         
    ;Draws a pixel at the position specified by CX and DX, with color stored in AL.
                push    bx
                mov     ah, 0ch
                mov     bl, 0
                mov     cx, di
                add     cx, x_temp
                mov     dx, si
                add     dx, y_temp
                int     10h
                pop     bx

            continue_bitmap_loop: 
    ;Go to the next pixel.
                dec     bx
                dec     di
                jnz     loop_x_bitmap

            add     bx, 151d
            dec     si
            jnz     loop_y_bitmap

        ret

    load_piece endp

    ;-----------------------------------------------------------------------------------------------------------------------------------------------

    ;Closes the bitmap file.
    close_file proc

        mov     ah, 3Eh
        mov     bx, [file_handle]
        call    check_file_error
        int     21h

        ret

    close_file endp

    ;-------------------------------------------------------------------------------------------------------------------------------------------------

    ;Returns color of the cell specified by SI(x-pos) & DI(y-pos) in AL
    get_cell_colour proc

        push    di
    
        add     di, si
        and     di, 1
        mov     al, board_colors[di]
                          
        pop     di

        ret
    
    get_cell_colour endp

; I think its pretty clear
    drawBorder proc

        push    si
        push    di
        push    bx
        push    cx
        push    dx
        push    bp

        add     si, margin_x
        add     di, margin_y

        mov     ah, 0ch
        push    ax

        mov     ax, si
        mul     cell_size
        mov     si, ax

        mov     ax, di
        mul     cell_size
        mov     di, ax
                         
        pop     ax

        mov     bp, 3d
        mov     dx, 1

        add     dx, di

        line1_1:
            mov cx, 1

            line1_2:
                add cx, si
                int 10h
                sub cx, si

                inc cx
                cmp cx, cell_size
                jnz line1_2

            inc dx
            dec bp
            jnz line1_1

                          
        mov bp, 3d
        add cx, si

        line2_1:
            mov dx, 1

            line2_2:  
                add dx, di
                int 10h
                sub dx, di

                inc dx
                cmp dx, cell_size
                jnz line2_2

            dec cx
            dec bp
            jnz line2_1
                        
                          
        mov bp, 3d
        add dx, di

        line3_1:
            mov cx, cell_size

            line3_2:
                add cx, si                        
                int 10h
                sub cx, si

                dec cx
                cmp cx, 1d
                jnz line3_2 

            dec dx
            dec bp
            jnz line3_1


        mov bp,3
        add cx, si

        line4_1:  
            mov dx, cell_size

            line4_2:
                add dx, di
                int 10h
                sub dx, di
                dec dx
                cmp dx, 1d
                jnz line4_2

            inc cx
            dec bp
            jnz line4_1
                          

        pop bp
        pop dx
        pop cx
        pop bx
        pop di
        pop si

        ret
    
    drawBorder endp

    ;Draws a piece
    draw_piece proc

        pusha

        add     si, margin_x        ;Adjust the column position using the x_margin.
        add     di, margin_y        ;Adjust the row position using the y_margin.
        push    si
        push    di
        call    get_file_handle     ;Prepare the file handle for other interrupts
        call    pass_file_header    ;Move the file pointer to the starting point of the image
        pop     di
        pop     si
        call    load_piece          ;Draw the image at the rows and columns specified by SI and DI.
        call    close_file          ;Close the file
                         
        popa
                         
        ret

    draw_piece endp

    ;-------------------------------------------------------------------------------------------------------------------------------------------------

    ;Draws a cell at the row and columns positions specified by SI and DI.
draw_cell proc

    ;Adjust SI and DI for the margins
                          push  bx
                          push  si
                          push  di
                          add   si, margin_x
                          add   di, margin_y

    ;Calculate and store the actual row and column positions of the upper left corner of each cell, and place them in SI and DI
                          mov   ah, 0ch
                          push  ax
                          mov   ax, si
                          mul   cell_size
                          mov   si, ax

                          mov   ax, di
                          mul   cell_size
                          mov   di, ax
                         
                          pop   ax
                         
    ;Prepare for drawing the cell.
                          mov   cx, cell_size
                          add   cx, si

    loop_x_cell:          
                          mov   dx, cell_size
    loop_y_cell:          
    ;CX and DX store the row and columns positions for INT 10H.
                          add   dx, di
                          int   10h

                          sub   dx, di
                          dec   dx
                          jnz   loop_y_cell
                          dec   cx
                          cmp   cx, si
                          jnz   loop_x_cell

    ;After drawing the cell, we now wish to draw the piece in the cell (if any).

    ;Get back the original row and column positions (from 0 to 7).
                
                          pop   di
                          pop   si
                      
                        
    ;From SI and DI, get the position of the cell we are drawing in board array, which contains the current state of the board.
                          mov   bx, di
    ;Multiplies by 8, we don't need to move 3 to register first in this assembler. We multiply the row number by 8 since each row has 8 positions.
                          shl   bx, 3
                          add   bx, si
                          add   bx, offset board
                          mov   ah, [bx]
                          mov   bh, 0
                          cmp   ah, 0

    ;If the current element in the board array contains 0, we draw no pieces.
    ;If it contains a negative value, we draw a white piece.
    ;If it contains a positive value, we draw a black piece.
                          je    finish_draw_cell
                          jl    draw_white_piece
    ;Drawing a black piece
    draw_black_piece:     
                          mov   bl, ah
                          shl   bl, 1
    ;Move the offset of the file we wish to access and draw to dx
                          mov   dx, word ptr [black_pieces + bx]
                          call  draw_piece
                          jmp   finish_draw_cell
    ;White Mate
    draw_white_piece:     
                          neg   ah
                          mov   bl, ah
                          shl   bl, 1
    ;Move the offset of the file we wish to access and draw to dx
                          mov   dx, word ptr [white_pieces + bx]
                          call  draw_piece
    ;Exiting
    finish_draw_cell:     pop bx
                          ret
draw_cell endp


    ;-------------------------------------------------------------------------------------------------------------------------------------------


    ;Calls draw_cell in a nested loop to display the whole board.
draw_board proc

    ;Position of the first (upper left) cell
                          mov   si, 0
                          mov   di, 0
    ;Color of the first cell
    ;   mov  al, byte ptr cell_colors
                         
    loop_y_board:         
                          mov   si, 0
    loop_x_board:         
    ;Draw the current cell
                          call  get_cell_colour
    ;   push ax
                          call  draw_cell
    ;   pop  ax
    ;Update the color of the cell for the next iteration
    ;                       cmp  al, byte ptr cell_colors
    ;                       jz   change_to_dark_color
    ; ; change_to_light_color:
    ;                       mov  al, byte ptr cell_colors
    ;                       jmp  continue_board_loop
    ; change_to_dark_color:
    ;                       mov  al, byte ptr cell_colors + 1
    ; continue_board_loop:
                          inc   si
                          cmp   si, 8
                          jnz   loop_x_board
                         
    ;Before going to the next iteration of the outer loop, reverse the color of the cell
    ;                       cmp  al, byte ptr cell_colors
    ;                       jz   set_dark_color
    ;                       mov  al, byte ptr cell_colors
    ;                       jmp  new_iteration
    ; set_dark_color:
    ;                       mov  al, byte ptr cell_colors + 1
    new_iteration:        
                          inc   di
                          cmp   di, 8
                          jnz   loop_y_board

                          ret
draw_board endp


    ;delays according to no. of 'delay_loops' in memory



clear_keyboard_buffer PROC

                          push  ax
    
                          mov   ah, 0Ch
                          mov   al,0
                          int   21h

                          pop   ax

                          ret
clear_keyboard_buffer ENDP

    ;Moves the piece (if possible) according to the scan codes of keys pressed (A->1E, D->20, W->11, S->1F)
hover PROC

                          push  cx
                          push  dx

    ; Storing current positons [DX,CX]
                          mov   cx,si
                          mov   dx,di
    
                          cmp   ah, 1Eh
                          jz    move_left

                          cmp   ah, 20h
                          jz    move_right

                          cmp   ah, 11h
                          jz    move_up

                          cmp   ah, 1Fh
                          jz    move_down

                          jmp   dont_move

    move_left:            
                          cmp   si, 0
                          jz    dont_move
                          dec   si
                          jmp   redraw

    move_right:           
                          cmp   si, 7h
                          jz    dont_move
                          inc   si
                          jmp   redraw
    move_up:              
                          cmp   di, 0h
                          jz    dont_move
                          dec   di
                          jmp   redraw
    move_down:            
                          cmp   di, 7h
                          jz    dont_move
                          inc   di
                          jmp   redraw


    redraw:               
    ; Redraw the prev cell with its original color
                          push  si
                          push  di
                          mov   si, cx
                          mov   di, dx
                          mov   al, temp_color
                          call  draw_cell
                          pop   di
                          pop   si

    dont_move:            
                          pop   dx
                          pop   cx
                          ret

hover ENDP

    ;Gets pos given SI,DI and puts it in BX
getPos PROC
                          push  si
                          push  di

                          shl   di,3h
                          add   di, si

                          mov   bx, di

                          pop   di
                          pop   si

                          ret
getPos ENDP


    ;Writes possible moves to memory
recordMove PROC
                          push  bx
                          push  ax

                          mov   al, directionPtr
                          mov   bl, 14d                             ; directionPtr * 7 * 2
                          mov   bh, 0

                          mul   bl
                          mov   bl, al

                          shl   currMovePtr,1
                          add   bl, currMovePtr
                          shr   currMovePtr, 1

                          mov   possibleMoves_DI[bx], di
                          mov   possibleMoves_SI[bx], si

                          ;inc   currMovePtr

                          pop   ax
                          pop   bx
                          ret
recordMove ENDP

; puts the current position as the first possible move in all directions
recordCurrPos PROC
                         push cx

                         mov cx, 8d
recordCurrPos_loop:
                         call recordMove
                         inc directionPtr

                         loop recordCurrPos_loop

                         mov directionPtr, 0d
                         mov currMovePtr, 1d

                         pop cx

                         ret
    
recordCurrPos ENDP
    ; Navigates in possible moves array
getNextPossibleMove PROC
                          push  bx
                          push  ax

                          mov   al, directionPtr
                          mov   bl, 14d                             ; directionPtr * 7 * 2
                          mov   bh, 0

                          mul   bl
                          mov   bl, al

                          shl   currMovePtr,1
                          add   bl, currMovePtr
                          shr   currMovePtr, 1

                          mov   di, possibleMoves_DI[bx]
                          mov   si, possibleMoves_SI[bx]

                          pop   ax
                          pop   bx
                          ret
getNextPossibleMove ENDP



    ;Changes the positions of selected move and puts them in SI & DI for drawing border
goToNextSelection PROC

                          push  ax
                          push  bx
                          push  cx
                          push  dx
                          push  bp

    ; preserving current positions
                          mov   bp, si
                          mov   dx, di
    ; preserving current move
                          mov bh, directionPtr
                          mov bl, currMovePtr


    ; Checking which key was pressed
                          cmp   ah, 1Eh
                          jz    A

                          cmp   ah, 20h
                          jz    D

                          cmp   ah, 11h
                          jz    W

                          cmp   ah, 1Fh
                          jz    S

                          jmp   doNotChangeSelection


    ; a rough implementation of (i+1)%n for both A & D
    A:                    
                          mov currMovePtr,1d
                          mov   cx, 7d
    aLoop:                
                          dec   directionPtr
                          cmp   directionPtr, -1d
                          jz    aLoopReset
    continueLoopA:        
                          call  getNextPossibleMove
                          cmp   si, -1d
                          jz   next_loopA_line
                          jmp far ptr changeSelection ; jump is far down
    next_loopA_line:      loop  aLoop
                          jmp   doNotChangeSelection
    aLoopReset:           
                          mov   directionPtr, 7d
                          jmp   continueLoopA


    D:                    
                          mov   cl, 7d
                          mov   ch, 8d
                          mov   al, directionPtr
                          mov   ah, 0d
                          mov currMovePtr, 1d
    dLoop:                
                          inc   al
                          div   ch
                          mov   al,ah
                          mov   directionPtr, al
    
                          call  getNextPossibleMove

                          cmp   si, -1d
                          jnz   changeSelection

                          dec   cl
                          jnz   dLoop
                          jmp   doNotChangeSelection

    W:                    
                          cmp   currMovePtr, 6
                          jz    doNotChangeSelection

                          inc   currMovePtr

                        ; if a move actually exists, change selection
                          call  getNextPossibleMove
                          cmp   si, -1d
                          jnz   changeSelection
                          
                          dec   currMovePtr
                          jmp   doNotChangeSelection

    S:                    
                          cmp   currMovePtr, 0
                          jz    doNotChangeSelection

                          dec   currMovePtr

                          call  getNextPossibleMove
                          cmp   si, -1d
                          jnz   changeSelection

                          jmp   doNotChangeSelection


    doNotChangeSelection: 
                        ; resets everything to its original state
                          mov directionPtr, bh
                          mov currMovePtr, bl
                          mov   si, bp
                          mov   di, dx
                          jmp   goToNextSelection_end
                        
    changeSelection:      
                        ; highlighting the previous possible move
                          push si
                          push di
                          
                          mov si, bp 
                          mov di, dx 

                          mov al, highlighted_cell_color
                          call draw_cell

                          pop di
                          pop si
                          

goToNextSelection_end:    
                          pop   bp
                          pop   dx
                          pop   cx
                          pop   bx
                          pop   ax
                          ret
goToNextSelection ENDP


;Moves to SI DI the first available position if possible
checkFirstAvailableMove PROC
                          push si
                          push di
                          push cx

                          mov cx, 8
                          mov currMovePtr, 1d
                          mov directionPtr, 0d
                          
first_available_direction:
                          call getNextPossibleMove
                          cmp si, -1d
                          jnz found_first_available_position
                          inc directionPtr
                          cmp directionPtr, 8d
                          jnz first_available_direction



                          ; to let us know if there aren't any available positions 
                          mov directionPtr, -1d                          
                          mov currMovePtr, -1d                          


found_first_available_position:
                          pop cx
                          pop di
                          pop si
                          ret
checkFirstAvailableMove ENDP

; puts 
getFirstSelection PROC
                          call checkFirstAvailableMove
                          cmp directionPtr, -1d
                          jz getFirstSelection_end
                          
                        ; to move the si, di corresponding to directionPtr & currMovPtr that we got from checkFirstAvailableMove
                          call getNextPossibleMove

                          mov al,00h
                          call drawBorder


getFirstSelection_end:    ret                          
getFirstSelection ENDP

; Removes previously selected cells (if any)
removeSelections PROC
                          push si
                          push di


                          mov directionPtr, 0d
                          
removeSelections_loop1:          
                          mov currMovePtr, 0d
    removeSelections_loop2:  
                          mov si, -1d
                          mov di, -1d

                          call recordMove
                          inc currMovePtr

                          cmp currMovePtr, 7d
                          jz removeSelections_loop2_break

                          call getNextPossibleMove
                          cmp si,-1
                          jz removeSelections_loop2_break

                          call get_cell_colour
                          call draw_cell

                          jmp removeSelections_loop2

removeSelections_loop2_break:
                          inc directionPtr
                          cmp directionPtr, 8d
                          jnz removeSelections_loop1


                          mov directionPtr, 0d
                          mov currMovePtr, 0d

                          pop di
                          pop si
                          ret
removeSelections ENDP

    ; Gets all possible pawn moves
getPawnMoves PROC
                          push  di
                          push  ax

                          add   di, walker
        
                          call  recordMove
                          inc currMovePtr

                          mov   al, highlighted_cell_color
                          call  draw_cell

                          cmp   walker, -1
                          jz    white
                          jmp   black



    white:                cmp   di, 6d
                          add   di, walker

                          call  recordMove
                          inc currMovePtr
    
                          call  draw_cell
                          jmp   gotPawnMoves
    

    black:                cmp   di, 1d
                          add   di, walker

                          call  recordMove
                          inc currMovePtr                          

                          call  draw_cell

    gotPawnMoves:         pop   ax
                          pop   di
                          ret

getPawnMoves ENDP

game_window proc

                        call  init_board                          ;Initialize board
                          call  init_video_mode                     ;Prepare video mode

    ;Clear the screen, in preparation for drawing the board
                          mov   al, 14h                             ;The color by which we will clear the screen (light gray).
                          call  clear_screen

                        call set_board

                          call  draw_board                          ;Draw the board
                         
    ;Listen for keyboard press and change its colour
                          mov   si,0
                          mov   di,7d

                          


    start:              
                          call removeSelections
                          call  get_cell_colour
                          mov   temp_color, al
                          cmp   ax,ax
                          
                          

    breathe:              cmp   al, temp_color
                          jz    highlight
                          jmp   darken

              

    draw:                 call  draw_cell
                          
                          mov   delay_loops,10d
                          call  delay

    ; Checks for keyboard input
                          mov   ah,1
                          int   16h

                          jnz   check
                          jmp   breathe
    
    
    highlight:            mov   al, highlighted_cell_color
                          jmp   draw


    darken:               mov   al, temp_color
                          jmp   draw


    check:                
    ;Consumes keyboard buffer
                          mov   ah,0
                          int   16h
    ; Before moving hover, check if a piece is selected
    ; If one is selected, show all possible moves

                          cmp   ah, 10h
                          jz    show_possible_moves

                          call  hover

                          jmp   start

    show_possible_moves:       
                          ; don't select an empty cell                                          
                          call  getPos

                          cmp   board[bx], 0d
                          jz    breathe

                          mov   currSelectedPos_DI, di
                          mov   currSelectedPos_SI, si
                          
                          call  recordCurrPos
                          
                          mov   al, highlighted_cell_color
                          call  draw_cell
                          


                          cmp   board[bx], -1
                          jz    white_pawn
                          cmp   board[bx], 1
                          jz    black_pawn

                          jmp   start_selection
                          
    black_pawn:           mov   walker, 1
                          jmp   get_pawn_positions

    white_pawn:           mov   walker, -1
    get_pawn_positions:   call  getPawnMoves
                          jmp start_selection
    


                          
    start_selection:      call getFirstSelection


                          
    same_selection:        
                          cmp   ax,ax
                          
                          mov   ah,1
                          int   16h

                          jnz   change_event
                          jmp   same_selection


    change_event:          
    ;Consumes keyboard buffer
                          mov   ah,0
                          int   16h

    ; The key is now in ah
    ; Before changing move, checks if:

                          ; another key other than Q is pressed
                          cmp   ah, 10h
                          jnz  go_to_next_selection


                          ; a piece wants to be moved
                          cmp si, currSelectedPos_SI
                          jnz move_piece

                          cmp di, currSelectedPos_DI
                          jnz move_piece


                          ; deselects the cell it is curr on (will be modified)
                          jmp far ptr start

go_to_next_selection:     
                        ; save current positions

                          call  goToNextSelection    
 

                          mov al, 00h
                          call drawBorder

                          jmp   same_selection
                          
move_piece:

ret

game_window endp

    set_board proc

        pusha

        ;preparing to draw the board base with interrupt 10
        mov cx, 226d    ;initial column
        mov dx, 76d     ;initial row
        mov al, 08d     ;color
        mov ah, 0ch     ;display

        ;looping in y and x
        loop_y:

            loop_x:
                int 10h
                inc cx
                cmp cx, 975d
                jnz loop_x

            mov cx, 226d
            inc dx
            cmp dx, 825d
            jnz loop_y

        popa

        ret

    set_board endp

    ;-------------------------------------------------------------------------------------------------------------------------------------------

    main_window proc

        main_start:
            pusha

            mov ax, 0600h
            mov bh, 07
            mov cx, 0
            mov dx, 184Fh
            int 10h

            mov ah, 2
            mov bh, 0
            mov dl, 1Ah
            mov dh, 07h
            int 10h

            mov ah, 9
            mov dx, offset cmd1
            int 21h

            mov ah, 2
            mov bh, 0
            mov dl, 1Ah
            mov dh, 0Bh
            int 10h

            mov ah, 9
            mov dx, offset cmd2
            int 21h

            mov ah, 2
            mov bh, 0
            mov dl, 1Ah
            mov dh, 0Fh
            int 10h

            mov ah, 9
            mov dx, offset cmd3
            int 21h

            mov ah, 0
            int 16h

            cmp ah, 3Bh
            jz start_chat

            cmp ah, 3Ch
            jz start_game

            cmp ah, 01h
            jz main_end

            jmp main_end

            start_chat:
                call chat_window
                jmp main_start

            start_game:
                mov ah, 2
                mov dl, 7
                int 21h

                call game_window
                jmp main_start

        main_end:

        popa

        ret

    main_window endp

    ;-------------------------------------------------------------------------------------------------------------------------------------------

    chat_window proc

        pusha

        mov ax, 0600h
        mov bh, 07
        mov cx, 0
        mov dx, 184Fh
        int 10h

        mov ah, 2
        mov bh, 0
        mov dl, 38d
        mov dh, 00h
        int 10h

        mov ah, 9
        mov dx, offset chat_title
        int 21h

        mov ah, 2
        mov bh, 0
        mov dl, 00h
        mov dh, 01h
        int 10h

        mov ah, 9
        mov bh, 0
        mov al, 45d
        mov cx, 80d
        mov bl, 003h
        int 10h

        mov ah, 2
        mov bh, 0
        mov dl, 38d
        mov dh, 02h
        int 10h

        mov ah, 9
        mov dx, offset temp_name
        int 21h

        mov ah, 2
        mov bh, 0
        mov dl, 00h
        mov dh, 03h
        int 10h

        mov ah, 9
        mov bh, 0
        mov al, 45d
        mov cx, 80d
        mov bl, 003h
        int 10h

        mov ah, 2
        mov bh, 0
        mov dl, 00h
        mov dh, 04h
        int 10h

        mov ah, 9
        mov dx, offset dummy
        int 21h

        mov ah, 2
        mov bh, 0
        mov dl, 32d
        mov dh, 08h
        int 10h

        mov ah, 9
        mov dx, offset dummy2
        int 21h

        chat_end:
            mov ah, 0
            int 16h

            cmp ah, 3Dh
            jnz chat_end

        popa

        ret

    chat_window endp

    ;-------------------------------------------------------------------------------------------------------------------------------------------

    welcome proc

        pusha

        mov ax, 0600h
        mov bh, 07
        mov cx, 0
        mov dx, 184Fh
        int 10h

        mov ah, 2
        mov bh, 0
        mov dl, 00d
        mov dh, 00d
        int 10h

        popa

        ret

    welcome endp

main proc far
    ;Initializing the data segment register
                          mov   ax, @data
                          mov   ds, ax

    ;Setting working directory to the folder containing bitmaps of the pieces
                          mov   ah, 3bh
                          mov   dx, offset pieces_wd
                          int   21h

                        call game_window
                          
halt:                     hlt
main endp
end main