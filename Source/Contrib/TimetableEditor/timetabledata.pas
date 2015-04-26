unit timetabledata;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,FileUtil,charencstreams, zipper;

type
  timearray = array[0..2] of integer;

procedure Split (const Delimiter: Char; Input: string; const Strings: TStringlist);
procedure setroutepath(path: String);
function getroutepath(): String;
procedure opentimetable(path: String);
procedure ListFileDir(Path: string; extension: String; FileList: TStrings);
procedure loadConsists(path: string);
function getconsists(): tstringlist;
function getconsistspath(): string;
procedure setselectedconsist(con: string);
function getselectedconsist():String;
function getconsistslistsize(): integer;
procedure createlists();
procedure loadpaths(path: String);
function getpaths(): tstringlist;
function getpathspath(): String;
procedure setselectedpath(path: String);
function getselectedpath(): String;
function getpathslistsize(): integer;
function getStations(): tstringlist;
function getStationsSize(): integer;
procedure addstation(station: String);
function extractstations(tdb: tstringlist): integer;
procedure liststationsfiles();
function getstationsfiles(): tstringlist;
function getstationsfilescount(): integer;
function loadstations(path: String): tStringlist;
function getRow(bez: String): integer;
procedure setRow(bez: String; val: String);
procedure setCol(cl: integer);
function getCol():integer;
function getpathnames: tstringlist;
procedure loadpathnames;
procedure loadConsistsnames();
function getconsistsnames: tstringlist;
function zaehl(str: string; zeichen: String): integer;
function splitzeit(zeit: string):timearray;
function returntime(zeit: integer): String;
function calctime(zeit1: timearray; zeit2: timearray): timearray;
function extracttime(zeit: String): tstringlist;
function zipdata(filename: String): boolean;
function isInList(item: String; list: tstringlist): boolean;
function extractcons(item: string): tstringlist;
function entsorg(item: String): String;
function getconsisttypes: tstringlist;

resourceString
  irgendwas = 'irgendas';

implementation

uses unit1;


var
   routepath,consistspath,pathspath: string;
   consistslist, consistnameslist, consisttypeslist, pathslist, pathnameslist: tstringlist;
   selectedconsist, selectedpath: string;
   stationslist, stationsfiles: tstringlist;
   col: integer;

procedure Split (const Delimiter: Char; Input: string; const Strings: TStringlist);
begin
   Assert(Assigned(Strings)) ;
   Strings.Clear;
   Strings.StrictDelimiter := true;
   Strings.Delimiter := Delimiter;
   Strings.DelimitedText := Input;
end;

function zaehl(str: string; zeichen: String): integer;
var i: integer;
begin
  result:=0;
  for i:=1 to length(str) do begin
    if str[i] = zeichen then inc(result);
  end;
end;

function splitzeit(zeit: string):timearray;
var res: array[0..2] of integer;
begin
  if zaehl(zeit,':') = 1 then begin
    res[0]:= strtoint(trim(copy(zeit,1,pos(':',zeit)-1)));
    res[1]:= strtoint(trim(copy(zeit,pos(':',zeit)+1,length(zeit))));
    res[2]:=-1;
  end;
  if zaehl(zeit,':') = 2 then begin
    res[0]:=strtoint(trim(copy(zeit,1,pos(':',zeit)-1)));
    delete(zeit,1,pos(':',zeit));
    res[1]:=strtoint(trim(copy(zeit,1,pos(':',zeit)-1)));
    res[2]:=strtoint(trim(copy(zeit,pos(':',zeit)+1,length(zeit))));
  end;
  result:=res;
end;

function returntime(zeit: integer): String;
begin
  if zeit < 10 then result:='0'+inttostr(zeit)
  else result:=inttostr(zeit);
end;

function calctime(zeit1: timearray; zeit2: timearray): timearray;
var hour, min, sec: integer;
     rzeit: timearray;
begin
  if ( zeit1[2] >-1 ) or ( zeit2[2] >-1 ) then begin
    if zeit1[2] = -1 then zeit1[2]:=0;
    if zeit2[2] = -1 then zeit2[2]:=0;
    sec:=zeit1[2]+zeit2[2];
    if sec >= 60 then begin
      sec:=sec -60;
      zeit2[1]:=zeit2[1]+1;
    end;
  end else sec:=-1;
  min:=zeit1[1]+zeit2[1];
  if min >= 60 then begin
    min:=min -60;
    zeit2[0]:=zeit2[0]+1;
    if zeit2[0] = 24 then zeit2[0]:= 0;
  end;
  hour:=zeit1[0]+zeit2[0];
  if hour >= 24 then hour:=hour -24;
  rzeit[0]:=hour;
  rzeit[1]:=min;
  rzeit[2]:=sec;
  result:=rzeit;
end;

function extracttime(zeit: String): tstringlist;
var i,p: integer;
    zt1, zt2, data: string;
    retlist: tstringlist;
begin
  retlist:=tstringlist.create;
  zt1:='';
  zt2:='';
  data:='';
  for i:=1 to length(zeit) do begin
    if ( zeit[i] =' ' ) or ( zeit[i] = '$' ) or ( zeit[i] ='/' ) then begin
      zt1:=trim(copy(zeit,1,i-1));
      data:=trim(copy(zeit,i,length(zeit)));
      break;
    end;
  end;
  if zt1='' then zt1:=zeit;
  if pos('-',zt1) > 0 then begin
    zt2:=copy(zt1,pos('-',zt1)+1,length(zt1));
    zt1:=copy(zt1,1,pos('-',zt1)-1);
  end;
  if pos('$create=',data) > 0 then begin
    i:=pos('$create=',data);
    p:=pos(' ',data);
    if p <= 0 then p:=length(data);
    zt2:=copy(data,i+length('$create='),p-i-length('$create=')+1);
    delete(data,pos('$create=',data),length('$create=')+length(zt2));
    data:=trim(data);
  end;
  retlist.add(zt1);
  retlist.add(zt2);
  retlist.add(data);
  result:=retlist;
end;

procedure setroutepath(path: String);
begin
  routepath:=path;
end;

function getroutepath():String;
begin
  result:=routepath;
end;

procedure opentimetable(path: String);
var i: integer;
    rpath: tstringlist;
begin
  rpath:=tstringlist.create;
  split('\',utf8tosys(path),rpath);
  routepath:='';
  i:=0;
  while ansilowercase(rpath[i]) <> 'routes' do begin
    routepath:=routepath+rpath[i]+'\';
    i:=i+1;
  end;
  routepath:=routepath + rpath[i] + '\'+ rpath[i+1] + '\';
  setroutepath(routepath);
  consistspath:='';
  i:=0;
  while ansilowercase(rpath[i]) <> 'routes' do begin
    consistspath:=consistspath+rpath[i]+'\';
    i:=i+1;
  end;
  consistspath:=consistspath+'trains\consists\';
  loadconsists(consistspath);
  pathspath:=routepath+'paths\';
  loadpaths(pathspath);
end;


function extractstations(tdb: tstringlist):integer;
var i,s,co: integer;
    station, tmp: string;
    found: boolean;
begin
  stationslist:=tstringlist.create;
  co:=0;
  for i:= 0 to tdb.Count -1 do begin
      if pos('Station',tdb[i]) > 0 then begin
        co:=co+1;
        tmp:=StringReplace(tdb[i], #9, '', [rfReplaceAll]);
        tmp:=StringReplace(tdb[i], '"','', [rfReplaceAll]);
        tmp:=leftstr(tmp, length(tmp) -1);
        station:=trim(copy(tmp,pos('(',tmp)+1,length(tmp)));
        if stationslist.count < 1 then stationslist.add(station)
        else begin
          found:=false;
          for s:= 0 to stationslist.count -1 do begin
            if stationslist[s] = station then found:=true;
          end;
          if found = false then stationslist.add(station);
        end;
      end;
    end;
  result:=co;
end;

function loadstations(path: String): tStringlist;
var fCES: TCharEncStream;
    tmp: tStringlist;
begin
  tmp:=tstringlist.create;
  fCES := TCharEncStream.Create;
  fCES.Reset;
  fCES.LoadFromFile(path);
  tmp.text := fces.UTF8Text;
  fces.free;
  result:=tmp;
end;

procedure liststationsfiles();
begin
  stationsfiles:=tstringlist.create;
  listfiledir(routepath+'Activities\Openrails\','*.stations', stationsfiles);
end;

procedure ListFileDir(Path: string; extension: String; FileList: TStrings);
var
   SR: TSearchRec;
begin
   if FindFirst(Path + extension, faAnyFile, SR) = 0 then
   begin
     repeat
       if (SR.Attr <> faDirectory) then
       begin
         FileList.Add(systoutf8(SR.Name));
       end;
     until FindNext(SR) <> 0;
     FindClose(SR);
   end;
end;

procedure loadConsists(path: string);
var i:integer;
begin
  consistslist:=tstringlist.create;
  listfiledir(path,'*.con',consistslist);
  for i:=0 to consistslist.Count -1 do begin
    consistslist[i]:=leftstr(consistslist[i],length(consistslist[i])-4);
  end;
  loadconsistsnames;
end;

procedure loadConsistsnames();
var i,n: integer;
   tmp: tstringlist;
   fCES: TCharEncStream;
   zeile: string;
   found, eng: boolean;
begin
  consistnameslist:=tstringlist.create;
  consisttypeslist:=tstringlist.create;
  for i:= 0 to consistslist.count -1 do begin
    tmp:=tstringlist.create;
    fCES := TCharEncStream.Create;
    fCES.Reset;
    fCES.loadfromfile(utf8tosys(consistspath+'\'+consistslist[i]+'.con'));
    tmp.text:=fces.UTF8Text;
    fces.free;
    found:=false;
    eng:=false;
    for n:= 0 to tmp.count -1 do begin
      if pos('Name',tmp[n]) > 0 then begin
        found:=true;
        zeile:=trim(tmp[n]);
        zeile:=copy(zeile,7,length(zeile)-7);
        zeile:=stringreplace(zeile,'"','',[rfReplaceAll]);
        zeile:=trim(zeile);
        consistnameslist.add(zeile)
      end;
      if pos('Engine (',tmp[n]) > 0 then eng:=true;
    end;
    if not found then consistnameslist.add(consistslist[i]);
    if eng then consisttypeslist.add('e') else consisttypeslist.add('w');
  end;
end;

procedure loadpaths(path: String);
var i:integer;
begin
  pathslist:=tstringlist.create;
  listfiledir(path,'*.pat',pathslist);
  for i:= 0 to pathslist.count -1 do begin
    pathslist[i]:=leftstr(pathslist[i],length(pathslist[i])-4);
  end;
  loadpathnames;
end;

procedure loadpathnames;
var i,n: integer;
   tmp: tStringlist;
   fCES: TCharEncStream;
   zeile: string;
   found: boolean;
begin
  pathnameslist:=tstringlist.create;
  for i:= 0 to pathslist.count -1 do begin
    tmp:=tstringlist.create;
    fCES := TCharEncStream.Create;
    fCES.Reset;
    fCES.LoadFromFile(utf8tosys(pathspath+'\'+pathslist[i]+'.pat'));
    tmp.text := fces.UTF8Text;
    fces.free;
    found:=false;
    for n:= 0 to tmp.Count -1 do begin
      if ( pos('Name',tmp[n]) > 0 ) and ( pos('TrPathName',tmp[n]) = 0 ) then begin
        found:=true;
        zeile:=trim(tmp[n]);
        zeile:=copy(zeile,7,length(zeile)-7);
        zeile:=stringreplace(zeile,'"','',[rfReplaceAll]);
        zeile:=trim(zeile);
        pathnameslist.Add(zeile);
      end;
    end;
    if not found then pathnameslist.add(pathslist[i]);
  end;
end;

function getconsists(): tstringlist;
begin
  result:=consistslist;
end;

function getconsistsnames: tstringlist;
begin
  result:=consistnameslist;
end;

function getconsisttypes: tstringlist;
begin
  result:=consisttypeslist;
end;

function getconsistspath(): string;
begin
  result:=consistspath;
end;

function getconsistslistsize(): integer;
begin
  result:=consistslist.Count;
end;

procedure setselectedconsist(con: string);
begin
  selectedconsist:=con;
end;

function getselectedconsist():String;
begin
  result:=selectedconsist;
end;

procedure createlists();
begin
  consistslist:=tstringlist.create;
  pathslist:=tstringlist.create;
end;

function getpaths(): tstringlist;
begin
  result:=pathslist;
end;

function getpathnames(): tstringlist;
begin
  result:=pathnameslist;
end;

function getpathspath(): String;
begin
  result:=pathspath;
end;

function getselectedpath(): String;
begin
  result:=selectedpath;
end;

procedure setselectedpath(path: String);
begin
  selectedpath:=path;
end;

function getpathslistsize(): integer;
begin
  result:=pathslist.count;
end;

function getStations(): tstringlist;
begin
  result:=stationslist;
end;

function getStationsSize(): integer;
begin
  result:=stationslist.Count;
end;

procedure addstation(station: String);
begin
  stationslist.add(station);
end;

function getstationsfiles(): tstringlist;
begin
  result:=stationsfiles;
end;

function getstationsfilescount(): integer;
begin
  result:=stationsfiles.Count;
end;

function getRow(bez: String): integer;
var r, res: integer;
begin
  res:=-1;
  for r:=0 to form1.grid.RowCount -1 do begin
    if pos(ansilowercase(bez),ansilowercase(form1.grid.cells[0,r]))>0 then begin
      res:=r;
      break;
    end;
  end;
  result:=res;
end;

procedure setRow(bez: String; val: String);
var r, res: integer;
begin
  res:=-1;
  for r:=0 to form1.grid.RowCount -1 do begin
    if pos(ansilowercase(bez),ansilowercase(form1.grid.cells[0,r]))>0 then begin
      res:=r;
      break;
    end;
  end;
  if res > -1 then form1.grid.Cells[col,res]:=val;
end;

procedure setCol(cl: integer);
begin
  col:=cl;
end;

function getCol():integer;
begin
  result:=col;
end;

function zipdata(filename: String): boolean;
var zpaths, zcons, con: tstringlist;
    i, prow, n: integer;
    zips: tzipper;
    item: String;
begin
  zips:=tzipper.create;
  zpaths:=tstringlist.create;
  zcons:=tstringlist.create;
  con:=tstringlist.create;
  prow:=-11;
  prow:=getrow('#path');
  for i:=1 to form1.grid.ColCount -1 do begin
    if form1.grid.cells[i,prow] <> '' then begin
      item:=form1.grid.cells[i,prow];
      if pos('/',item) > 0 then item:=trim(leftstr(item,pos('/',item)-1));
      item:=pathspath+item+'.pat';
      if ( zpaths.Count = 0 ) or ( isinlist(item,zpaths) = false ) then zpaths.add(item);
      end;
  end;
  prow:=getrow('#consist');
  for i:=1 to form1.grid.colcount -1 do begin
    if form1.grid.cells[i,prow] <> '' then begin
      item:=form1.grid.cells[i,prow];
      con:=extractcons(item);
      for n:=0 to con.count -1 do begin
        item:=trim(con[n]);
        item:=consistspath+item+'.con';
        if ( zcons.count = 0 ) or ( isinlist(item,zcons) = false ) then begin
          zcons.Add(item);
        end;
      end;
    end;
  end;
  try

    zips.FileName:=utf8tosys(filename);
    zips.entries.addfileentry(ttfilename);
    for i:=0 to zpaths.count -1 do begin
      zips.Entries.AddFileEntry(utf8tosys(zpaths[i]),utf8tosys(zpaths[i]));
    end;
    for i:=0 to zcons.count -1 do begin
      zips.Entries.addfileentry(utf8tosys(zcons[i]),utf8tosys(zcons[i]));
    end;
    zips.ZipAllFiles;
  finally
    zips.Free;
  end;

end;


function extractcons(item: string): tstringlist;
var i: integer;
    list: tstringlist;
    ins: boolean;
    it: String;
begin
  ins:=false;
  list:=tstringlist.create;
  if ( pos('<',item) < 1 ) and ( pos('>',item) < 1 ) and ( pos ('+',item) < 1 ) then begin
    list.add(entsorg(trim(item)));
  end else begin
    for i:= 1 to length(item) do begin
      if item[i] = '<' then ins:=true;
      if ( ins = false ) and ( item[i] = '+' ) then begin
          list.add(entsorg(trim(copy(item,1,i-1))));
          delete(item,1,i);
        end;
      if item[i] = '>' then begin
        ins:=false;
        list.add(entsorg(trim(copy(item,1,i))));
        delete(item,1,i+1);
      end;
    end;
    if length(item) > 0 then list.add(trim(item));
  end;
  i:=0;
  while i < list.count -1 do begin
    if list[i] = '' then begin
      list.delete(i);
      i:=i-1;
    end;
    i:=i+1;
  end;
  result:=list;
end;

function entsorg(item: String): String;
begin
  item:=trim(item);
  item:=trim(stringreplace(item,'$reverse','',[rfReplaceAll, rfIgnoreCase]));
  item:=trim(stringreplace(item,'<','',[rfReplaceAll, rfIgnoreCase]));
  item:=trim(stringreplace(item,'>','',[rfReplaceAll, rfIgnoreCase]));
  result:=item;
end;

function isInList(item: String; list: tstringlist): boolean;
var i: integer;
    found: boolean;
begin
  found:=false;
  for i:= 0 to list.count -1 do begin
    if item = list[i] then found:=true;
  end;
  result:=found;
end;

end.

