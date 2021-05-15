(*
#    $Id: nwpre.as,v 1.3 2003/03/25 18:17:54 armin Exp $
#    This file is part of the Free Pascal run time library.
#    Copyright (c) 1999-2011 by the Free Pascal development team
#    Copyright (c) 2002-2011 Armin Diehl
#
#    This is the (nwpre-like) startup code for netware (clib)
#
#    See the file COPYING.FPC, included in this distribution,
#    for details about the copyright.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
#**********************************************************************
# This version initializes BSS
#
# Imported functions will not be known by the linker because only the
# generated object file will be included into the link process. The
# ppu will not be read. Therefore the file nwpre.imp containing the
# names of all imported functions needs to be created. This file
# will be used by the internal linker to import the needed functions.
#**********************************************************************
*)

unit nwpre;

interface

implementation


procedure _SetupArgV_411 (startProc:pointer); cdecl; external 'clib' name '_SetupArgV_411';
procedure _nlm_main; external  name '_nlm_main';
procedure FPC_NW_CHECKFUNCTION; external name 'FPC_NW_CHECKFUNCTION';
function _StartNLM (NLMHandle              : longint;
                   initErrorScreenID       : longint;
                   cmdLineP                : pchar;
                   loadDirectoryPath       : pchar;
                   uninitializedDataLength : longint;
                   NLMFileHandle           : longint;
                   readRoutineP            : pointer;
                   customDataOffset        : longint;
                   customDataSize          : longint;
                   NLMInformation          : pointer;
                   userStartFunc           : pointer) : longint; cdecl; external '!clib' name '_StartNLM';
                                                                                                                                                                                                                                                          

function _TerminateNLM  (NLMInformation          : pointer;
                         threadID, status        : longint) : longint; cdecl; external '!clib' name '_TerminateNLM';


procedure _Stop; cdecl; forward;

// This is the main program (not loader) Entry-Point that will be called by netware    
// it sets up the argc and argv and calls _nlm_main (in system.pp)

procedure _pasStart; assembler; export; [alias:'_pasStart_'];
asm
    pushl	$_nlm_main
    call	_SetupArgV_411
    addl	$4,%esp
    ret
// this is a hack to avoid that FPC_NW_CHECKFUNCTION will be
// eleminated by the linker (with smartlinking)
// TODO: change the internal linker to allow check and stop
    call	FPC_NW_CHECKFUNCTION
    call	_Stop
end;


// structure needed by clib
type kNLMInfoT =
   packed record
      Signature      : array [0..3] of char;	// LONG 'NLMI'
      Flavor         : longint;			// TRADINIONAL_FLAVOR = 0
      Version        : longint;			// TRADINIONAL_VERSION = 0, LIBERTY_VERSION = 1
      LongDoubleSize : longint;			// gcc nwpre defines 12, watcom 8
      wchar_tSize    : longint;
    end;

var 
  _kNLMInfo:kNLMInfoT = (Signature:'NLMI';Flavor:0;Version:1;LongDoubleSize:8;wChar_tSize:2);


// symbol is generated by the internal linker, when using ld in the future again,
// the link script for ld needs to be modified to include this symbol
 bss : ptruint; external name '__bss_start__';


// fillchar
// netware kernel function
procedure CSetB(value:byte; var addr; count:longint); cdecl; external '!' name 'CSetB';


// this will be called by the loader, we pass the address of _pasStart_ and
// _kNLMInfo (needed by clib) and clib will call _pasStart within a newly
// created thread
function _Prelude (NLMHandle               : longint;
                   initErrorScreenID       : longint;
                   cmdLineP                : pchar;
                   loadDirectoryPath       : pchar;
                   uninitializedDataLength : longint;
                   NLMFileHandle           : longint;
                   readRoutineP            : pointer;
                   customDataOffset        : longint;
                   customDataSize          : longint) : longint; cdecl; export; [alias:'_Prelude'];
begin
  // initialize BSS
  CSetB(0,bss,uninitializedDataLength);

  // let clib setup a thread and call pasStart in this new thread
  _Prelude := _StartNLM (NLMHandle,
                         initErrorScreenID,
                         cmdLineP,
                         loadDirectoryPath,
                         uninitializedDataLength,
                         NLMFileHandle,
                         readRoutineP,
                         customDataOffset,
                         customDataSize,
                         @_kNLMInfo,
                         @_pasStart);
end;

(*
procedure _Prelude; assembler; export; [alias:'_Prelude'];
asm
       	pushl	%ebp
    	movl	%esp,%ebp
       	pushl	%edi
       	pushl	%esi
   	pushl	%ebx
     	movl	0x14(%ebp),%edi
     	movl	0x18(%ebp),%esi
	movl	%esi, __uninitializedDataSize
     	movl	0x1c(%ebp),%ebx
     	movl	0x20(%ebp),%ecx
     	movl	0x28(%ebp),%eax
   	pushl	$_pasStart
   	pushl	$_kNLMInfo
   	pushl	%eax
     	movl	0x24(%ebp),%edx  // 1b7f6
   	pushl	%edx
       	pushl	%ecx  
   	pushl	%ebx
       	pushl	%esi			// uninitialized data size
       	pushl	%edi
     	movl	0x10(%ebp),%edx
   	pushl	%edx
     	movl	0xc(%ebp),%edx
   	pushl	%edx
     	movl	0x8(%ebp),%edx
 	pushl	%edx
       	call	_StartNLM
	test	%eax,%eax
    	jne	.Lx1
    	xorl	%eax,%eax		// dont know why this is needed ?
.Lx1:
     	lea	0xfffffff4(%ebp),%esp
   	popl	%ebx
       	popl	%esi
       	popl	%edi
    	movl	%ebp,%esp
   	popl	%ebp
   	ret
end;
*)

//# the global stop-function

// fpc will generate an (unneeded) stack frame here, gcc does not
(*
procedure _Stop; cdecl; export; [alias:'_Stop'];
begin
  _TerminateNLM (@_kNLMInfo,0,5);
end;
*)

procedure _Stop; cdecl; assembler; [alias:'_Stop'];
asm
	pushl	$0x5
	pushl	$0x0
	movl	_kNLMInfo,%edx
	pushl	%edx
	call	_TerminateNLM
	addl	$0x0c,%esp
	ret
end;

end.
