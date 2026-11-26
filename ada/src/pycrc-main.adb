--  pycrc -- parameterisable CRC calculation utility and Ada source generator.
--
--  Copyright (c) 2006-2017  Thomas Pircher  <tehpeh-web@tty1.net>
--
--  Permission is hereby granted, free of charge, to any person obtaining a copy
--  of this software and associated documentation files (the "Software"), to
--  deal in the Software without restriction, including without limitation the
--  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
--  sell copies of the Software, and to permit persons to whom the Software is
--  furnished to do so, subject to the following conditions:
--
--  The above copyright notice and this permission notice shall be included in
--  all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
--  IN THE SOFTWARE.

with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces;
with PyCRC.Algorithms;
with PyCRC.Codegen;
with PyCRC.Options;

--  The driver reads arguments and files and writes the checksum. Those
--  libraries are not in SPARK; the arithmetic is PyCRC.Algorithms.
procedure PyCRC.Main
  with SPARK_Mode => Off
is

   use Ada.Strings.Unbounded;

   function Make (Opt : Options.Settings) return Algorithms.Calculator is
     (Algorithms.Create
        (Width           => Width_Type (Opt.Width),
         Poly            => Opt.Poly,
         Reflect_In      => Opt.Reflect_In,
         Xor_In          => Opt.Xor_In,
         Reflect_Out     => Opt.Reflect_Out,
         Xor_Out         => Opt.Xor_Out,
         Table_Idx_Width =>
           Algorithms.Table_Index_Width (Opt.Table_Idx_Width)));

   function Selected
     (Opt : Options.Settings; Data : Byte_Array) return Interfaces.Unsigned_64
   is
      Calc     : constant Algorithms.Calculator := Make (Opt);
      BBB      : Interfaces.Unsigned_64 := 0;
      BBF      : Interfaces.Unsigned_64 := 0;
      Tbl      : Interfaces.Unsigned_64 := 0;
      CRC      : Interfaces.Unsigned_64 := 0;
      Mismatch : Boolean;
   begin
      if Opt.Algorithm.Bit_By_Bit then
         BBB := Algorithms.Bit_By_Bit (Calc, Data);
         CRC := BBB;
      end if;
      if Opt.Algorithm.Bit_By_Bit_Fast then
         BBF := Algorithms.Bit_By_Bit_Fast (Calc, Data);
         CRC := BBF;
      end if;
      if Opt.Algorithm.Table_Driven then
         Tbl := Algorithms.Table_Driven (Calc, Data);
         CRC := Tbl;
      end if;
      Mismatch :=
        (Opt.Algorithm.Bit_By_Bit
         and then Opt.Algorithm.Bit_By_Bit_Fast
         and then BBB /= BBF)
        or else (Opt.Algorithm.Bit_By_Bit
                 and then Opt.Algorithm.Table_Driven
                 and then BBB /= Tbl)
        or else (Opt.Algorithm.Bit_By_Bit_Fast
                 and then Opt.Algorithm.Table_Driven
                 and then BBF /= Tbl);

      if Mismatch then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "pycrc: error: different checksums!");
         if Opt.Algorithm.Bit_By_Bit then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "       bit-by-bit:        " & Hex_Image (BBB));
         end if;
         if Opt.Algorithm.Bit_By_Bit_Fast then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "       bit-by-bit-fast:   " & Hex_Image (BBF));
         end if;
         if Opt.Algorithm.Table_Driven then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "       table_driven:      " & Hex_Image (Tbl));
         end if;
         raise Parameter_Error;
      end if;
      return CRC;
   end Selected;

   function Parse_Hex (Text : String) return Byte_Array is
      use Ada.Characters.Handling;
      Source : constant String :=
        (if Text'Length mod 2 = 1 then "0" & Text else Text);
      Result : Byte_Array (1 .. Source'Length / 2);
      Pos    : Positive := Source'First;

      function Value (C : Character) return Natural is
      begin
         if C in '0' .. '9' then
            return Character'Pos (C) - Character'Pos ('0');
         elsif C in 'a' .. 'f' or else C in 'A' .. 'F' then
            return Character'Pos (To_Lower (C)) - Character'Pos ('a') + 10;
         else
            Die ("invalid hex string " & Text);
         end if;
      end Value;
   begin
      for I in Result'Range loop
         Result (I) :=
           Byte (Value (Source (Pos)) * 16 + Value (Source (Pos + 1)));
         Pos := Pos + 2;
      end loop;
      return Result;
   end Parse_Hex;

   function Check_File
     (Opt : Options.Settings) return Interfaces.Unsigned_64
   is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      Calc   : constant Algorithms.Calculator := Make (Opt);
      File   : File_Type;
      Reg    : Interfaces.Unsigned_64 := Algorithms.Direct_Init (Calc);
      Buffer : Stream_Element_Array (1 .. 4096);
      Last   : Stream_Element_Offset;
      Name   : constant String := To_String (Opt.Check_File);
   begin
      begin
         Open (File, In_File, Name);
      exception
         when Name_Error | Use_Error =>
            Die ("can't open file " & Name);
      end;

      loop
         Read (File, Buffer, Last);
         exit when Last < Buffer'First;
         declare
            Chunk : Byte_Array (1 .. Natural (Last));
         begin
            for J in Chunk'Range loop
               Chunk (J) :=
                 Byte (Buffer (Stream_Element_Offset (J)));
            end loop;
            Reg := Algorithms.Direct_Update (Calc, Reg, Chunk);
         end;
      end loop;
      Close (File);
      return Algorithms.Direct_Finalize (Calc, Reg);
   end Check_File;

   Opt : Options.Settings;
begin
   Opt := Options.Parse;
   if Opt.Stop then
      return;
   end if;

   if Opt.Verbose then
      Ada.Text_IO.Put_Line (Options.Parameter_Block (Opt));
   end if;

   case Opt.Action is
      when Options.Check_String =>
         Ada.Text_IO.Put_Line
           (Hex_Image (Selected (Opt, To_Bytes (To_String (Opt.Check_String)))));
      when Options.Check_Hexstring =>
         Ada.Text_IO.Put_Line
           (Hex_Image
              (Selected (Opt, Parse_Hex (To_String (Opt.Check_String)))));
      when Options.Check_File =>
         Ada.Text_IO.Put_Line (Hex_Image (Check_File (Opt)));
      when Options.Generate =>
         Codegen.Generate (Opt);
   end case;
exception
   when Parameter_Error =>
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end PyCRC.Main;
