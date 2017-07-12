unit HdfFile;

interface

{-$DEFINE Debug}

uses
  ECMA.TypedArray;

type
  EHdfInvalidFormat = class(Exception);

  THdfSignature = String;

  JZlibInflate = class external 'Zlib.Inflate'
    constructor Create(compressed: JUint8Array);
    function decompress: Variant;
  end;

  TStream = class
  private
    FPosition: Integer;
    FDataView: JDataView;
  public
    constructor Create(Buffer: JArrayBuffer);

    function ReadTextExcept(const Count: Integer {$IFDEF Debug}; const ErrorMessage: String{$ENDIF}): String; overload;
    function ReadIntegerExcept(const Count: Integer {$IFDEF Debug}; const ErrorMessage: String{$ENDIF}): Integer; overload;
    function ReadBufferExcept(const Count: Integer {$IFDEF Debug}; const ErrorMessage: String{$ENDIF}): JUint8Array; overload;

    procedure WriteInteger(const Count: Integer; Value: Integer);
    procedure Clear;

    function Seek(Position: Integer; IsRelative: Boolean = False): Integer;

    property DataView: JDataView read FDataView;
    property Size: Integer read (FDataView.buffer.byteLength);
    property Position: Integer read FPosition write FPosition;
  end;

  THdfSuperBlock = class
  private
    FFormatSignature: String;
    FVersion: Integer;
    FConsistencyFlag: Integer; // was Byte
    FOffsetSize: Integer; // was Byte
    FLengthsSize: Integer; // was Byte
    FBaseAddress: Integer; // was Int64
    FSuperBlockExtensionAddress: Integer; // was Int64
    FEndOfFileAddress: Integer; // was Int64
    FRootGroupObjectHeaderAddress: Integer; // was Int64
    FChecksum: Integer;
  public
    procedure LoadFromStream(Stream: TStream);
    procedure SaveToStream(Stream: TStream);

    property OffsetSize: Integer read FOffsetSize;
    property LengthsSize: Integer read FLengthsSize;
    property EndOfFileAddress: Integer read FEndOfFileAddress;
  end;

  THdfDataObject = class;

  THdfDataObjectMessage = class
  private
    FSuperBlock: THdfSuperBlock;
  protected
    FVersion: Integer; // was Byte
    FDataObject: THdfDataObject;
    property Superblock: THdfSuperBlock read FSuperBlock;
    property DataObject: THdfDataObject read FDataObject;
  public
    constructor Create(SuperBlock: THdfSuperBlock; DataObject: THdfDataObject);

    procedure LoadFromStream(Stream: TStream); virtual;
    procedure SaveToStream(Stream: TStream);

    property Version: Integer read FVersion;
  end;

  THdfMessageDataSpace = class(THdfDataObjectMessage)
  private
    FDimensionality: Integer; // was Byte
    FFlags: Integer; // was Byte
    FType: Integer; // was Byte
    FDimensionSize: array of Integer; // was Int64
    FDimensionMaxSize: array of Integer; // was Int64
    function GetDimension(Index: Integer): Integer;
  public
    procedure LoadFromStream(Stream: TStream); override;

    property Dimensionality: Integer read FDimensionality;
    property Dimension[Index: Integer]: Integer read GetDimension;
  end;

  THdfMessageLinkInfo = class(THdfDataObjectMessage)
  private
    FFlags: Integer; // was Byte
    FMaximumCreationIndex: Integer; // was Int64
    FFractalHeapAddress: Integer; // was Int64
    FAddressBTreeIndex: Integer; // was Int64
    FAddressBTreeOrder: Integer; // was Int64
  public
    procedure LoadFromStream(Stream: TStream); override;

    property FractalHeapAddress: Integer read FFractalHeapAddress;
  end;

  THdfMessageDataType = class;

  THdfBaseDataType = class
  protected
    FDataTypeMessage: THdfMessageDataType;
  public
    constructor Create(DatatypeMessage: THdfMessageDataType); virtual;

    procedure LoadFromStream(Stream: TStream); virtual;
    procedure SaveToStream(Stream: TStream);
  end;

  THdfDataTypeFixedPoint = class(THdfBaseDataType)
  private
    FBitOffset: Integer; // was Word
    FBitPrecision: Integer; // was Word
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfDataTypeFloatingPoint = class(THdfBaseDataType)
  private
    FBitOffset: Integer; // was Word
    FBitPrecision: Integer; // was Word
    FExponentLocation: Integer; // was Byte
    FExponentSize: Integer; // was Byte
    FMantissaLocation: Integer; // was Byte
    FMantissaSize: Integer; // was Byte
    FExponentBias: Integer;
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfDataTypeTime = class(THdfBaseDataType)
  private
    FBitPrecision: Integer; // was Word
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfDataTypeString = class(THdfBaseDataType);

  THdfDataTypeBitfield = class(THdfBaseDataType)
  private
    FBitOffset: Integer; // was Word
    FBitPrecision: Integer; // was Word
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfDataTypeOpaque = class(THdfBaseDataType);

  THdfDataTypeCompoundPart = class
  private
    FName: String;
    FByteOffset: Integer; // was Int64
    FSize: Integer; // was Int64
    FDataType: THdfMessageDataType;
  public
    constructor Create(DatatypeMessage: THdfMessageDataType); virtual;

    procedure ReadFromStream(Stream: TStream);
  end;

  THdfDataTypeCompound = class(THdfBaseDataType)
  private
    FDataTypes: array of Variant;
  public
    constructor Create(DatatypeMessage: THdfMessageDataType); override;
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfDataTypeReference = class(THdfBaseDataType);
  THdfDataTypeEnumerated = class(THdfBaseDataType);
  THdfDataTypeVariableLength = class(THdfBaseDataType)
  private
    FDataType: THdfMessageDataType;
  public
    constructor Create(DatatypeMessage: THdfMessageDataType); override;
    procedure LoadFromStream(Stream: TStream); override;
  end;
  THdfDataTypeArray = class(THdfBaseDataType);

  THdfMessageDataType = class(THdfDataObjectMessage)
  private
    FDataClass: Integer; // was Byte
    FClassBitField: array [0..2] of Integer; // was Byte
    FSize: Integer;
    FDataType: THdfBaseDataType;
  public
    procedure LoadFromStream(Stream: TStream); override;

    property Size: Integer read FSize;
    property DataClass: Integer read FDataClass;
  end;

  THdfMessageDataFill = class(THdfDataObjectMessage)
  private
    FFlags: Integer; // was Byte
    FSize: Integer;
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfMessageDataLayout = class(THdfDataObjectMessage)
  private
    FLayoutClass: Integer; // was Byte
    FDataAddress: Integer; // was Int64
    FDataSize: Integer; // was Int64
    FDimensionality: Integer; // was Byte
    procedure ReadTree(Stream: TStream; Size: Integer);
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfMessageGroupInfo = class(THdfDataObjectMessage)
  private
    FFlags: Integer; // was Byte
    FMaximumCompact: Integer; // was Word
    FMinimumDense: Integer; // was Word
    FEstimatedNumberOfEntries: Integer; // was Word
    FEstimatedLinkNameLength: Integer; // was Word
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfMessageFilterPipeline = class(THdfDataObjectMessage)
  private
    FFilters: Integer; // was Byte
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfAttribute = class
  private
    FName: String;
    FStream: TStream;
    function GetValueAsString: String;
    procedure SetValueAsString(const Value: String);
    function GetValueAsInteger: Integer;
    procedure SetValueAsInteger(const Value: Integer);
  public
    constructor Create(Name: String);

    property Name: String read FName;
    property ValueAsString: String read GetValueAsString write SetValueAsString;
    property ValueAsInteger: Integer read GetValueAsInteger write SetValueAsInteger;
  end;

  THdfMessageAttribute = class(THdfDataObjectMessage)
  private
    FFlags: Integer; // was Byte
    FNameSize: Integer; // was Word
    FDatatypeSize: Integer; // was Word
    FDataspaceSize: Integer; // was Word
    FEncoding: Integer; // was Byte
    FName: String;
    FDatatypeMessage: THdfMessageDataType;
    FDataspaceMessage: THdfMessageDataSpace;

    procedure ReadData(Stream: TStream; Attribute: THdfAttribute);
    procedure ReadDataDimension(Stream: TStream; Attribute: THdfAttribute;
      Dimension: Integer);
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfMessageHeaderContinuation = class(THdfDataObjectMessage)
  private
    FOffset: Integer; // was Int64
    FLength: Integer; // was Int64
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfMessageAttributeInfo = class(THdfDataObjectMessage)
  private
    FFlags: Integer; // was Byte
    FMaximumCreationIndex: Integer; // was Word
    FFractalHeapAddress: Integer; // was Int64
    FAttributeNameBTreeAddress: Integer; // was Int64
    FAttributeOrderBTreeAddress: Integer; // was Int64
  public
    procedure LoadFromStream(Stream: TStream); override;

    property FractalHeapAddress: Integer read FFractalHeapAddress;
  end;

  THdfFractalHeap = class
  private
    FSuperBlock: THdfSuperBlock;
    FDataObject: THdfDataObject;
    FSignature: THdfSignature;
    FVersion: Integer; // was Byte
    FHeapIdLength: Integer; // was Word
    FEncodedLength: Integer; // was Word
    FFlags: Integer; // was Byte
    FMaximumSize: Integer;
    FNextHugeID: Integer; // was Int64
    FBtreeAddresses: Integer; // was Int64
    FAmountFreeSpace: Integer; // was Int64
    FAddressManagedBlock: Integer; // was Int64
    FAmountManagedSpace: Integer; // was Int64
    FAmountAllocatedManagedSpace: Integer; // was Int64
    FOffsetDirectBlockAllocation: Integer; // was Int64
    FNumberOfManagedObjects: Integer; // was Int64
    FSizeOfHugeObjects: Integer; // was Int64
    FNumberOfHugeObjects: Integer; // was Int64
    FSizeOfTinyObjects: Integer; // was Int64
    FNumberOfTinyObjects: Integer; // was Int64
    FTableWidth: Integer; // was Word
    FStartingBlockSize: Integer; // was Int64
    FMaximumDirectBlockSize: Integer; // was Int64
    FMaximumHeapSize: Integer; // was Word
    FStartingNumber: Integer; // was Word
    FAddressOfRootBlock: Integer; // was Int64
    FCurrentNumberOfRows: Integer; // was Word
    FSizeOfFilteredRootDirectBlock: Integer; // was Int64
    FIOFilterMask: Integer;
  protected
    property SuperBlock: THdfSuperBlock read FSuperBlock;
  public
    constructor Create(SuperBlock: THdfSuperBlock; DataObject: THdfDataObject);
    procedure LoadFromStream(Stream: TStream);
    procedure SaveToStream(Stream: TStream);

    property MaximumSize: Integer read FMaximumSize;
    property MaximumDirectBlockSize: Integer read FMaximumDirectBlockSize;
    property MaximumHeapSize: Integer read FMaximumHeapSize;
    property StartingBlockSize: Integer read FStartingBlockSize;
    property Flags: Integer read FFlags;
    property TableWidth: Integer read FTableWidth;
    property EncodedLength: Integer read FEncodedLength;
  end;

  THdfCustomBlock = class
  private
    FSuperBlock: THdfSuperBlock;
    FSignature: THdfSignature;
    FVersion: Integer; // was Byte
    FHeapHeaderAddress: Integer; // was Int64
  protected
    FFractalHeap: THdfFractalHeap;
    FChecksum: Integer;
    FBlockOffset: Integer; // was Int64
    FDataObject: THdfDataObject;
    class function GetSignature: THdfSignature; virtual; abstract;

    property SuperBlock: THdfSuperBlock read FSuperBlock;
  public
    constructor Create(SuperBlock: THdfSuperBlock;
      FractalHeap: THdfFractalHeap; DataObject: THdfDataObject); virtual;

    procedure LoadFromStream(Stream: TStream); virtual;
    procedure SaveToStream(Stream: TStream);
  end;

  THdfDirectBlock = class(THdfCustomBlock)
  protected
    class function GetSignature: THdfSignature; override;
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  THdfIndirectBlock = class(THdfCustomBlock)
  private
    FInitialBlockSize: Integer; // was Int64
    FMaximumNumberOfDirectBlockRows: Integer;
  protected
    class function GetSignature: THdfSignature; override;
  public
    constructor Create(SuperBlock: THdfSuperBlock; FractalHeap: THdfFractalHeap;
      DataObject: THdfDataObject); override;

    procedure LoadFromStream(Stream: TStream); override;
  end;

  TArrayOfInteger = array of Integer;

  THdfDataObject = class
  private
    FName: String;
    FSuperBlock: THdfSuperBlock;
    FSignature: THdfSignature;
    FVersion: Integer; // was Byte
    FFlags: Integer; // was Byte
    FAccessTime: Integer;
    FModificationTime: Integer;
    FChangeTime: Integer;
    FBirthTime: Integer;
    FChunkSize: Integer; // was Int64
    FMaximumCompact: Integer; // was Word
    FMinimumDense: Integer; // was Word

    FDataLayoutChunk: TArrayOfInteger;

    FData: JUint8Array;
    FAttributeList: array of THdfAttribute;

    FDataType: THdfMessageDataType;
    FDataSpace: THdfMessageDataSpace;
    FLinkInfo: THdfMessageLinkInfo;
    FGroupInfo: THdfMessageGroupInfo;
    FAttributeInfo: THdfMessageAttributeInfo;

    FDataObjects: array of THdfDataObject;

    FAttributesHeap: THdfFractalHeap;
    FObjectsHeap: THdfFractalHeap;
    function GetDataObjectCount: Integer;
    function GetDataObject(Index: Integer): THdfDataObject;
    function GetDataLayoutChunk(Index: Integer): Integer;
    function GetDataLayoutChunkCount: Integer;
    function GetAttributeListCount: Integer;
    function GetAttributeListItem(Index: Integer): THdfAttribute;
  protected
    procedure ReadObjectHeaderMessages(Stream: TStream; EndOfStream: Integer);

    property Superblock: THdfSuperBlock read FSuperBlock;
    property AttributesHeap: THdfFractalHeap read FAttributesHeap;
    property ObjectsHeap: THdfFractalHeap read FObjectsHeap;
  public
    constructor Create(SuperBlock: THdfSuperBlock); overload;
    constructor Create(SuperBlock: THdfSuperBlock; Name: String); overload;

    procedure AddDataObject(DataObject: THdfDataObject);
    procedure AddAttribute(Attribute: THdfAttribute);

    procedure LoadFromStream(Stream: TStream);
    procedure SaveToStream(Stream: TStream);

    function HasAttribute(Name: string): Boolean;
    function GetAttribute(Name: string): string;

    property Name: String read FName;
    property Data: JUint8Array read FData write FData;
    property DataType: THdfMessageDataType read FDataType;
    property DataSpace: THdfMessageDataSpace read FDataSpace;
    property LinkInfo: THdfMessageLinkInfo read FLinkInfo;
    property GroupInfo: THdfMessageGroupInfo read FGroupInfo;
    property AttributeInfo: THdfMessageAttributeInfo read FAttributeInfo;

    property AttributeListCount: Integer read GetAttributeListCount;
    property AttributeListItem[Index: Integer]: THdfAttribute read GetAttributeListItem;
    property DataObjectCount: Integer read GetDataObjectCount;
    property DataObject[Index: Integer]: THdfDataObject read GetDataObject;
    property DataLayoutChunkCount: Integer read GetDataLayoutChunkCount;
    property DataLayoutChunk[Index: Integer]: Integer read GetDataLayoutChunk;
  end;

  THdfFile = class
  private
    FSuperBlock: THdfSuperBlock;
    FDataObject: THdfDataObject;
  public
    constructor Create;

    procedure LoadFromStream(Stream: TStream);
    procedure SaveToStream(Stream: TStream);

    procedure LoadFromBuffer(Buffer: JArrayBuffer);
    procedure SaveToBuffer(Buffer: JArrayBuffer);

    function HasAttribute(Name: string): Boolean;
    function GetAttribute(Name: string): string;

    property SuperBlock: THdfSuperBlock read FSuperBlock;
    property DataObject: THdfDataObject read FDataObject;
  end;

implementation

uses
  WHATWG.Console;

{ TStream }

constructor TStream.Create(Buffer: JArrayBuffer);
begin
  FPosition := 0;
  FDataView := JDataView.Create(Buffer);
end;

function TStream.ReadIntegerExcept(const Count: Integer{$IFDEF Debug};
  const ErrorMessage: String{$ENDIF}): Integer;
begin
  if FPosition + Count > FDataView.byteLength then
    raise Exception.Create(
      {$IFDEF Debug}'Error reading ' + ErrorMessage + '. ' + {$ENDIF}
      'Position exceeds byte length');

  case Count of
    1:
      Result := FDataView.getUint8(FPosition);
    2:
      Result := FDataView.getUint16(FPosition, True);
    3:
      Result := FDataView.getUint16(FPosition, True) + FDataView.getUint8(FPosition + 2) shl 16;
    4:
      Result := FDataView.getUint32(FPosition, True);
    5:
      Result := FDataView.getUint32(FPosition, True) or (FDataView.getUint8(FPosition + 4) shl 32);
    6:
      Result := FDataView.getUint32(FPosition, True) or (FDataView.getUint16(FPosition + 4, True) shl 32);
    8:
      Result := FDataView.getUint32(FPosition, True) or (FDataView.getUint32(FPosition + 4, True) shl 32);
    else
      raise Exception.Create({$IFDEF Debug}'Error reading ' + ErrorMessage{$ELSE}'Unknown bit width'{$ENDIF});
  end;

  Inc(FPosition, Count);
end;

function TStream.ReadTextExcept(const Count: Integer{$IFDEF Debug};
  const ErrorMessage: String{$ENDIF}): String;
begin
  if FPosition + Count > FDataView.byteLength then
    raise Exception.Create(
      {$IFDEF Debug}'Error reading ' + ErrorMessage + '. ' + {$ENDIF}
      'Position exceeds byte length');

  Result := '';
  for var Index := 0 to Count - 1 do
  begin
    var ByteValue := FDataView.getUint8(FPosition + Index);

    Result := Result + Chr(ByteValue);
  end;

  Inc(FPosition, Count);
end;

function TStream.ReadBufferExcept(const Count: Integer {$IFDEF Debug};
  const ErrorMessage: String{$ENDIF}): JUint8Array;
begin
  if FPosition + Count > FDataView.byteLength then
    raise Exception.Create(
      {$IFDEF Debug}'Error reading ' + ErrorMessage + '. ' + {$ENDIF}
      'Position exceeds byte length');

  Result := JUint8Array.Create(FDataView.buffer.slice(FPosition, FPosition + Count));
  Inc(FPosition, Count);
end;

function TStream.Seek(Position: Integer; IsRelative: Boolean = False): Integer;
begin
  FPosition := Position + if IsRelative then FPosition;
  if FPosition > FDataView.byteLength then
    FPosition := FDataView.byteLength;

  if FPosition > FDataView.byteLength then
    raise Exception.Create('Invalid Position');

  Result := FPosition;
end;

procedure TStream.WriteInteger(const Count: Integer; Value: Integer);
begin
  case Count of
    1:
      FDataView.setUint8(FPosition, Value);
    2:
      FDataView.setUint16(FPosition, Value);
    4:
      FDataView.setUint32(FPosition, Value);
    else
      raise Exception.Create('Invalid count');
  end;

  Inc(FPosition, Count);
end;

procedure TStream.Clear;
begin
  FPosition := 0;
end;


{ THdfSuperBlock }

procedure THdfSuperBlock.LoadFromStream(Stream: TStream);
begin
  var Identifier := Stream.ReadIntegerExcept(1{$IFDEF Debug}, 'signature'{$ENDIF});
  if Identifier <> 137 then
    raise Exception.Create('The file is not a valid HDF');

  FFormatSignature := Stream.ReadTextExcept(3{$IFDEF Debug}, 'signature'{$ENDIF});
  if FFormatSignature <> 'HDF' then
    raise Exception.Create('The file is not a valid HDF');

  var FormatSignatureVersion := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'signature'{$ENDIF});
  if FormatSignatureVersion <> 169478669 then // was 218765834
    raise Exception.Create('The file is not a valid HDF');

  // read version
  FVersion := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'version'{$ENDIF});
  if not (FVersion in [2, 3]) then
    raise Exception.Create('Unsupported version');

  // read offset & length size
  FOffsetSize := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'offset size'{$ENDIF});
  FLengthsSize := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'lengths size'{$ENDIF});

  // read consistency flag
  FConsistencyFlag := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'consistency flag'{$ENDIF});

  // read base address
  FBaseAddress := Stream.ReadIntegerExcept(FOffsetSize {$IFDEF DEBUG}, 'base address'{$ENDIF});

  // read superblock extension address
  FSuperBlockExtensionAddress := Stream.ReadIntegerExcept(FOffsetSize{$IFDEF DEBUG}, 'superblock extension address'{$ENDIF});

  // read end of file address
  FEndOfFileAddress := Stream.ReadIntegerExcept(FOffsetSize{$IFDEF DEBUG}, 'end of file address'{$ENDIF});

  // read group object header address
  FRootGroupObjectHeaderAddress := Stream.ReadIntegerExcept(FOffsetSize{$IFDEF DEBUG}, 'group object header address'{$ENDIF});

  if FBaseAddress <> 0 then
    raise Exception.Create('The base address should be zero');

  if FEndOfFileAddress <> Stream.Size then
    raise Exception.Create('Size mismatch');

  // read checksum
  FChecksum := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'checksum'{$ENDIF});

  // read checksum
  if Stream.Seek(FRootGroupObjectHeaderAddress) <> FRootGroupObjectHeaderAddress then
    raise Exception.Create('Error seeking first object');
end;

procedure THdfSuperBlock.SaveToStream(Stream: TStream);
begin
  raise Exception.Create('Not yet implemented');
end;


{ THdfDataObjectMessage }

constructor THdfDataObjectMessage.Create(SuperBlock: THdfSuperBlock; DataObject: THdfDataObject);
begin
  FSuperBlock := SuperBlock;
  FDataObject := DataObject;
end;

procedure THdfDataObjectMessage.LoadFromStream(Stream: TStream);
begin
  // read version
  FVersion := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'version'{$ENDIF});
end;

procedure THdfDataObjectMessage.SaveToStream(Stream: TStream);
begin
  raise Exception.Create('Not yet implemented');
end;


{ THdfMessageDataSpace }

procedure THdfMessageDataSpace.LoadFromStream(Stream: TStream);
var
  Index: Integer;
begin
  inherited LoadFromStream(Stream);

  if not (FVersion in [1, 2]) then
    raise Exception.Create('Unsupported version of dataspace message');

  // read dimensionality
  FDimensionality := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'dimensionality'{$ENDIF});

  // read flags
  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  // eventually skip reserved
  if FVersion = 1 then
  begin
    Stream.Seek(5, True);

    raise Exception.Create('Unsupported version of dataspace message');
  end;

  // read type
  FType := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'type'{$ENDIF});

  // read dimension size
  //SetLength(FDimensionSize, FDimensionality);
  for Index := 0 to FDimensionality - 1 do
  begin
    var Size := Stream.ReadIntegerExcept(Superblock.LengthsSize{$IFDEF DEBUG}, 'dimension size'{$ENDIF});
    FDimensionSize.Add(Size);
  end;

  // eventually read dimension max size
  if (FFlags and 1) <> 0 then
  begin
    for Index := 0 to FDimensionality - 1 do
    begin
      var MaxSize := Stream.ReadIntegerExcept(Superblock.LengthsSize{$IFDEF DEBUG}, 'dimension size'{$ENDIF});
      FDimensionMaxSize.Add(MaxSize);
    end
  end;
end;

function THdfMessageDataSpace.GetDimension(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= Length(FDimensionSize)) then
    raise Exception.Create(Format('Index out of bounds (%d)', [Index]));

  Result := FDimensionSize[Index];
end;


{ THdfBaseDataType }

constructor THdfBaseDataType.Create(DatatypeMessage: THdfMessageDataType);
begin
  FDataTypeMessage := DataTypeMessage;
end;

procedure THdfBaseDataType.LoadFromStream(Stream: TStream);
begin
  // do nothing by default
end;

procedure THdfBaseDataType.SaveToStream(Stream: TStream);
begin
  raise Exception.Create('Not yet implemented');
end;


{ THdfDataTypeFixedPoint }

procedure THdfDataTypeFixedPoint.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);

  FBitOffset := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'bit offset'{$ENDIF});
  FBitPrecision := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'bit precision'{$ENDIF});
end;


{ THdfDataTypeFloatingPoint }

procedure THdfDataTypeFloatingPoint.LoadFromStream(Stream: TStream);
begin
  FBitOffset := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'bit offset'{$ENDIF});
  FBitPrecision := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'bit precision'{$ENDIF});

  FExponentLocation := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'exponent location'{$ENDIF});
  FExponentSize := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'exponent size'{$ENDIF});
  FMantissaLocation := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'mantissa location'{$ENDIF});
  FMantissaSize := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'mantissa size'{$ENDIF});
  FExponentBias := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'exponent bias'{$ENDIF});

  if (FBitOffset <> 0) then
    raise Exception.Create('Unsupported bit offset');
  if (FMantissaLocation <> 0) then
    raise Exception.Create('Unsupported mantissa location');
  if (FBitPrecision = 32) then
  begin
    if (FExponentLocation <> 23) then
      raise Exception.Create('Unsupported exponent location');
    if (FExponentSize <> 8) then
      raise Exception.Create('Unsupported exponent size');
    if (FMantissaSize <> 23) then
      raise Exception.Create('Unsupported mantissa size');
    if (FExponentBias <> 127) then
      raise Exception.Create('Unsupported exponent bias');
  end else
  if (FBitPrecision = 64) then
  begin
    if (FExponentLocation <> 52) then
      raise Exception.Create('Unsupported exponent location');
    if (FExponentSize <> 11) then
      raise Exception.Create('Unsupported exponent size');
    if (FMantissaSize <> 52) then
      raise Exception.Create('Unsupported mantissa size');
    if (FExponentBias <> 1023) then
      raise Exception.Create('Unsupported exponent bias');
  end
  else
    raise Exception.Create('Unsupported bit precision');
end;


{ THdfDataTypeTime }

procedure THdfDataTypeTime.LoadFromStream(Stream: TStream);
begin
  FBitPrecision := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'bit precision'{$ENDIF});
end;


{ THdfDataTypeBitfield }

procedure THdfDataTypeBitfield.LoadFromStream(Stream: TStream);
begin
  FBitOffset := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'bit offset'{$ENDIF});
  FBitPrecision := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'bit precision'{$ENDIF});
end;


{ THdfDataTypeCompoundPart }

constructor THdfDataTypeCompoundPart.Create(DatatypeMessage: THdfMessageDataType);
begin
  FDataType := THdfMessageDataType.Create(DatatypeMessage.Superblock, DatatypeMessage.DataObject);
  FSize := DatatypeMessage.Size;
end;

procedure THdfDataTypeCompoundPart.ReadFromStream(Stream: TStream);
var
  ByteIndex: Integer;
  ByteValue: Integer;
  Temp: Integer; // was Byte
begin
  FName := '';
  repeat
    ByteValue := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'character byte'{$ENDIF});
    FName := FName + Chr(ByteValue);
  until ByteValue = 0;

  ByteIndex := 0;
  repeat
    Temp := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'value'{$ENDIF});
    FByteOffset := FByteOffset + Temp shl (8 * ByteIndex);
    Inc(ByteIndex);
  until 1 shl (8 * ByteIndex) > FSize;

  FDataType.LoadFromStream(Stream);
end;

{ THdfDataTypeCompound }

constructor THdfDataTypeCompound.Create(DatatypeMessage: THdfMessageDataType);
begin
  inherited Create(DatatypeMessage);

  //FDataTypes := TObjectList.Create;
end;

procedure THdfDataTypeCompound.LoadFromStream(Stream: TStream);
var
  Index: Integer;
  Count: Integer;
  Part: THdfDataTypeCompoundPart;
begin
  if (FDataTypeMessage.Version <> 3) then
    raise Exception.Create(Format('Error unsupported compound version (%d)', [FDataTypeMessage.Version]));

  Count := FDataTypeMessage.FClassBitField[1] shl 8 + FDataTypeMessage.FClassBitField[0];
  for Index := 0 to Count - 1 do
  begin
    Part := THdfDataTypeCompoundPart.Create(FDataTypeMessage);
    Part.ReadFromStream(Stream);
    FDataTypes.Add(Part);
  end;
end;


{ THdfDataTypeVariableLength }

constructor THdfDataTypeVariableLength.Create(
  DatatypeMessage: THdfMessageDataType);
begin
  inherited Create(DatatypeMessage);

  FDataType := THdfMessageDataType.Create(FDataTypeMessage.Superblock, FDataTypeMessage.DataObject);
end;

procedure THdfDataTypeVariableLength.LoadFromStream(Stream: TStream);
begin
  FDataType.LoadFromStream(Stream);
end;


{ THdfMessageDataType }

procedure THdfMessageDataType.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);

  // expand class and version
  FDataClass := FVersion and $F;
  FVersion := FVersion shr 4;

  // check version
  if not (FVersion in [1, 3]) then
    raise Exception.Create('Unsupported version of data type message');

  FClassBitField[0] := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'class bit field'{$ENDIF});
  FClassBitField[1] := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'class bit field'{$ENDIF});
  FClassBitField[2] := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'class bit field'{$ENDIF});

  FSize := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'size'{$ENDIF});

  case FDataClass of
    0:
      FDataType := THdfDataTypeFixedPoint.Create(Self);
    1:
      FDataType := THdfDataTypeFloatingPoint.Create(Self);
    2:
      FDataType := THdfDataTypeTime.Create(Self);
    3:
      FDataType := THdfDataTypeString.Create(Self);
    4:
      FDataType := THdfDataTypeBitfield.Create(Self);
    5:
      FDataType := THdfDataTypeOpaque.Create(Self);
    6:
      FDataType := THdfDataTypeCompound.Create(Self);
    7:
      FDataType := THdfDataTypeReference.Create(Self);
    8:
      FDataType := THdfDataTypeEnumerated.Create(Self);
    9:
      FDataType := THdfDataTypeVariableLength.Create(Self);
    10:
      FDataType := THdfDataTypeArray.Create(Self);
    else
      raise Exception.Create(Format('Unknown datatype (%d)', [FDataClass]));
  end;

  if Assigned(FDataType) then
    FDataType.LoadFromStream(Stream);
end;


{ THdfMessageDataFill }

procedure THdfMessageDataFill.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);

  // check version
  if FVersion <> 3 then
    raise Exception.Create('Unsupported version of data fill message');

  // read flags
  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  if (FFlags and (1 shl 5)) <> 0 then
  begin
    FSize := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'size'{$ENDIF});
    Stream.Seek(FSize, True);
  end;
end;


{ THdfMessageDataLayout }

procedure THdfMessageDataLayout.LoadFromStream(Stream: TStream);
var
  Index: Integer;
  StreamPos: Integer; // was Int64
  Size: Integer; // was Int64
begin
  inherited LoadFromStream(Stream);

  // check version
  if FVersion <> 3 then
    raise Exception.Create('Unsupported version of data layout message');

  FLayoutClass := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'layout class'{$ENDIF});
  case FLayoutClass of
    0: // compact storage
      begin
        // read data size
        FDataSize := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'data size'{$ENDIF});

        // read raw data
        DataObject.Data := Stream.ReadBufferExcept(FDataSize{$IFDEF DEBUG}, 'from buffer'{$ENDIF});
      end;
    1: // continous storage
      begin
        // compact storage
        FDataAddress := Stream.ReadIntegerExcept(Superblock.OffsetSize{$IFDEF DEBUG}, 'data address'{$ENDIF});
        FDataSize := Stream.ReadIntegerExcept(Superblock.LengthsSize{$IFDEF DEBUG}, 'data lengths'{$ENDIF});

        if FDataAddress > 0 then
        begin
          StreamPos := Stream.Position;
          Stream.Position := FDataAddress;

          DataObject.Data := Stream.ReadBufferExcept(FDataSize{$IFDEF DEBUG}, 'from buffer'{$ENDIF});

          Stream.Position := StreamPos;
        end;
      end;
    2:
      begin
        FDimensionality := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'dimensionality'{$ENDIF});
        FDataAddress := Stream.ReadIntegerExcept(Superblock.OffsetSize{$IFDEF DEBUG}, 'data address'{$ENDIF});
        for Index := 0 to FDimensionality - 1 do
        begin
          var DataLayoutChunk := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'data layout chunk'{$ENDIF});
          FDataObject.FDataLayoutChunk.Add(DataLayoutChunk);
        end;

        Size := DataObject.FDataLayoutChunk[FDimensionality - 1];
        for Index := 0 to DataObject.DataSpace.Dimensionality - 1 do
          Size := Size * DataObject.DataSpace.FDimensionSize[Index];

        if (FDataAddress > 0) and (FDataAddress < Superblock.EndOfFileAddress) then
        begin
          StreamPos := Stream.Position;
          Stream.Position := FDataAddress;

          ReadTree(Stream, Size);

          Stream.Position := StreamPos;
        end;
      end;
  end;
end;

procedure THdfMessageDataLayout.ReadTree(Stream: TStream; Size: Integer);
var
  Key: Integer; // was Int64
begin
  if DataObject.DataSpace.Dimensionality > 3 then
    raise EHdfInvalidFormat.Create('Error reading dimensions');

  // read signature
  var Signature := Stream.ReadTextExcept(4{$IFDEF Debug}, 'signature'{$ENDIF});
  if Signature <> 'TREE' then
    raise Exception.Create(Format('Wrong signature (%s)', [string(Signature)]));

  var NodeType := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'node type'{$ENDIF});
  var NodeLevel := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'node level'{$ENDIF});

  var EntriesUsed := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'entries used'{$ENDIF});
  var AddressLeftSibling := Stream.ReadIntegerExcept(Superblock.OffsetSize{$IFDEF DEBUG}, 'left sibling address'{$ENDIF});
  var AddressRightSibling := Stream.ReadIntegerExcept(Superblock.OffsetSize{$IFDEF DEBUG}, 'right sibling address'{$ENDIF});

  var Elements := 1;
  for var DimensionIndex := 0 to FDataObject.DataSpace.Dimensionality - 1 do
    Elements := Elements * FDataObject.DatalayoutChunk[DimensionIndex];

  var ElementSize := FDataObject.DatalayoutChunk[FDataObject.DataSpace.Dimensionality];

  var Output := JUint8Array.Create(Size);
  for var ElementIndex := 0 to 2 * EntriesUsed - 1 do
  begin
    if NodeType = 0 then
      Key := Stream.ReadIntegerExcept(Superblock.LengthsSize{$IFDEF DEBUG}, 'keys'{$ENDIF})
    else
    begin
      var ChunkSize := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'chunk size'{$ENDIF});
      var FilterMask := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'filter mask'{$ENDIF});
      if FilterMask <> 0 then
        raise Exception.Create('All filters must be enabled');

      var Start: array of Integer;
      for var DimensionIndex := 0 to DataObject.DataSpace.Dimensionality - 1 do
      begin
        var StartPos := Stream.ReadIntegerExcept(8{$IFDEF DEBUG}, 'start'{$ENDIF});
        Start.Add(StartPos);
      end;

      var BreakCondition := Stream.ReadIntegerExcept(8{$IFDEF DEBUG}, 'break condition'{$ENDIF});
      if BreakCondition <> 0 then
        Break;

      var ChildPointer := Stream.ReadIntegerExcept(Superblock.OffsetSize{$IFDEF DEBUG}, 'child pointer'{$ENDIF});

      // read data
      var StreamPos := Stream.Position;
      Stream.Position := ChildPointer;

      // read data from stream
      var ByteData := Stream.ReadBufferExcept(ChunkSize{$IFDEF DEBUG}, 'buffer'{$ENDIF});
      var Inflate := JZlibInflate.Create(ByteData);
      var Input := JUint8Array(Inflate.decompress);
      Assert(Input.byteLength = Elements * ElementSize);

      case DataObject.DataSpace.Dimensionality of
        1:
          begin
            var sx := DataObject.DataSpace.FDimensionSize[0];
            for var ByteIndex := 0 to Elements * ElementSize - 1 do
            begin
              var b := ByteIndex div Elements;
              var x := ByteIndex mod Elements + Start[0];
              if (x < sx) then
                Output[x * ElementSize + b] := Input[ByteIndex];
            end;
          end;
        2:
          begin
            var sx := DataObject.DataSpace.FDimensionSize[0];
            var sy := DataObject.DataSpace.FDimensionSize[1];
            var dy := DataObject.DataLayoutChunk[1];
            for var ByteIndex := 0 to Elements * ElementSize - 1 do
            begin
              var b := ByteIndex div Elements;
              var x := ByteIndex mod Elements;
              var y := x mod dy + Start[1];
              x := x div dy + Start[0];
              if (y < sy) and (x < sx) then
                Output[(x * sy + y) * ElementSize + b] := Input[ByteIndex];
            end;
          end;
        3:
          begin
            var sx := DataObject.DataSpace.FDimensionSize[0];
            var sy := DataObject.DataSpace.FDimensionSize[1];
            var sz := DataObject.DataSpace.FDimensionSize[2];
            var dy := DataObject.DataLayoutChunk[1];
            var dz := DataObject.DataLayoutChunk[2];
            for var ByteIndex := 0 to Elements * ElementSize - 1 do
            begin
              var b := ByteIndex div Elements;
              var x := ByteIndex mod Elements;
              var z := (x mod dz) + Start[2];
              var y := (x div dz) mod dy + Start[1];
              x := (x div (dy * dz)) + Start[0];
              if (z < sz) and (y < sy) and (x < sx) then
                Output[(x * sz * sy + y * sz + z) * ElementSize + b] := Input[ByteIndex];
            end;
          end;
      end;

      Stream.Position := StreamPos;
    end;
  end;

  if not Assigned(DataObject.Data) then
    DataObject.Data := Output
  else
  begin
    var OldData := DataObject.Data;
    DataObject.Data := JUint8Array.Create(OldData.byteLength + Output.byteLength);
    DataObject.Data.set(OldData, 0);
    DataObject.Data.set(Output, OldData.byteLength);
  end;

  var CheckSum := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'checksum'{$ENDIF});
end;


{ THdfMessageLinkInfo }

procedure THdfMessageLinkInfo.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);

  // check version
  if FVersion <> 0 then
    raise Exception.Create('Unsupported version of link info message');

  // read flags
  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  if (FFlags and 1) <> 0 then
    FMaximumCreationIndex := Stream.ReadIntegerExcept(8{$IFDEF DEBUG}, 'maximum creation index'{$ENDIF});

  FFractalHeapAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG},
    'maximum creation index'{$ENDIF});
  FAddressBTreeIndex := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG},
    'maximum creation index'{$ENDIF});

  if (FFlags and 2) <> 0 then
    FAddressBTreeOrder := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG},
      'maximum creation index'{$ENDIF});
end;


{ THdfMessageGroupInfo }

procedure THdfMessageGroupInfo.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);

  // check version
  if FVersion <> 0 then
    raise Exception.Create('Unsupported version of group info message');

  // read flags
  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  if (FFlags and 1) <> 0 then
  begin
    FMaximumCompact := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'maximum compact value'{$ENDIF});
    FMinimumDense := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'maximum compact value'{$ENDIF});
  end;

  if (FFlags and 2) <> 0 then
  begin
    FEstimatedNumberOfEntries := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'estimated number of entries'{$ENDIF});
    FEstimatedLinkNameLength := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'estimated link name length of entries'{$ENDIF});
  end;
end;


{ THdfMessageFilterPipeline }

procedure THdfMessageFilterPipeline.LoadFromStream(Stream: TStream);
var
  Index: Integer;
  FilterIdentificationValue: Integer; // was Word
  Flags, NumberClientDataValues: Integer; // was Word
  ValueIndex: Integer;
  ClientData: Integer;
begin
  inherited LoadFromStream(Stream);

  // check version
  if FVersion <> 2 then
    raise Exception.Create('Unsupported version of the filter pipeline message');

  FFilters := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'filters'{$ENDIF});
  if FFilters > 32 then
    raise Exception.Create('filter pipeline message has too many filters');

  for Index := 0 to FFilters - 1 do
  begin
    FilterIdentificationValue := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'filter identification value'{$ENDIF});
    if not FilterIdentificationValue in [1, 2] then
      raise Exception.Create('Unsupported filter');
    Flags := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'flags'{$ENDIF});
    NumberClientDataValues := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'number client data values'{$ENDIF});
    for ValueIndex := 0 to NumberClientDataValues - 1 do
      ClientData := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'client data'{$ENDIF});
  end;
end;


{ THdfAttribute }

constructor THdfAttribute.Create(Name: String);
begin
  FName := Trim(Name);
  FStream := TStream.Create(JArrayBuffer.Create(0));
end;

function THdfAttribute.GetValueAsString: String;
begin
  if FStream.Size = 0 then
  begin
    Result := '';
    Exit;
  end;

  Result := FStream.ReadTextExcept(FStream.Size{$IFDEF Debug}, 'value as string'{$ENDIF});
end;

procedure THdfAttribute.SetValueAsInteger(const Value: Integer);
begin
  FStream.Clear;
  FStream.WriteInteger(4, Value);
end;

function THdfAttribute.GetValueAsInteger: Integer;
begin
  FStream.Position := 0;
  Result := FStream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'value as integer'{$ENDIF});
end;

procedure THdfAttribute.SetValueAsString(const Value: String);
(*
var
  StringStream: TStringStream;
begin
  StringStream := TStringStream.Create(Trim(string(Value)));
  try
    FStream.Clear;
    FStream.CopyFrom(StringStream, StringStream.Size);
  finally
    StringStream.Free;
  end;
*)
begin
end;

{ THdfMessageAttribute }

procedure THdfMessageAttribute.ReadData(Stream: TStream; Attribute: THdfAttribute);
var
  Name: String;
  Value: Integer;
  Dimension: Integer;
  EndAddress: Integer;
begin
  case FDatatypeMessage.DataClass of
    3:
      begin
        SetLength(Name, FDatatypeMessage.Size);
        Name := Stream.ReadTextExcept(FDatatypeMessage.Size{$IFDEF Debug}, 'string'{$ENDIF});
        Attribute.ValueAsString := Name;
      end;
    6:
      begin
        // TODO
        Stream.Seek(FDatatypeMessage.Size, True);
      end;
    7:
      begin
        Value := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'value'{$ENDIF});
        Attribute.ValueAsInteger := Value;
        // TODO
      end;
    9:
      begin
        Dimension := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'dimension'{$ENDIF});
        EndAddress := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'end address'{$ENDIF});

        Value := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'value'{$ENDIF});
        Value := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'value'{$ENDIF});
        // TODO
      end;
    else
      raise Exception.Create('Error: unknown data class');
  end;
end;

procedure THdfMessageAttribute.ReadDataDimension(Stream: TStream;
  Attribute: THdfAttribute; Dimension: Integer);
var
  Index: Integer;
begin
  if Length(FDataspaceMessage.FDimensionSize) > 0 then
    for Index := 0 to FDataspaceMessage.FDimensionSize[0] - 1 do
    begin
      if (1 < FDataspaceMessage.Dimensionality) then
        ReadDataDimension(Stream, Attribute, Dimension + 1)
      else
        ReadData(Stream, Attribute);
    end;
end;

procedure THdfMessageAttribute.LoadFromStream(Stream: TStream);
var
  Attribute: THdfAttribute;
begin
  inherited LoadFromStream(Stream);

  // check version
  if FVersion <> 3 then
    raise Exception.Create('Unsupported version of group info message');

  // read flags
  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  FNameSize := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'name size'{$ENDIF});
  FDatatypeSize := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'datatype size'{$ENDIF});
  FDataspaceSize := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'dataspace size'{$ENDIF});
  FEncoding := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'encoding'{$ENDIF});

  FName := Stream.ReadTextExcept(FNameSize{$IFDEF Debug}, 'name'{$ENDIF});

  FDatatypeMessage := THdfMessageDataType.Create(Superblock, DataObject);
  FDatatypeMessage.LoadFromStream(Stream);

  FDataspaceMessage := THdfMessageDataSpace.Create(Superblock, DataObject);
  FDataspaceMessage.LoadFromStream(Stream);

  Attribute := THdfAttribute.Create(FName);
  DataObject.AddAttribute(Attribute);

  if FDataspaceMessage.Dimensionality = 0 then
    ReadData(Stream, Attribute)
  else
    ReadDataDimension(Stream, Attribute, 0);
end;

{ THdfMessageHeaderContinuation }

procedure THdfMessageHeaderContinuation.LoadFromStream(Stream: TStream);
var
  StreamPos: Integer;
  Signature: THdfSignature;
begin
  FOffset := Stream.ReadIntegerExcept(Superblock.OffsetSize{$IFDEF DEBUG}, 'offset'{$ENDIF});
  FLength := Stream.ReadIntegerExcept(Superblock.LengthsSize{$IFDEF DEBUG}, 'length'{$ENDIF});

  StreamPos := Stream.Position;
  Stream.Position := FOffset;

  // read signature
  Signature := Stream.ReadTextExcept(4{$IFDEF Debug}, 'signature'{$ENDIF});
  if Signature <> 'OCHK' then
    raise Exception.Create(Format('Wrong signature (%s)', [string(Signature)]));

  DataObject.ReadObjectHeaderMessages(Stream, FOffset + FLength);

  Stream.Position := StreamPos;
end;


{ THdfMessageAttributeInfo }

procedure THdfMessageAttributeInfo.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);

  // check version
  if FVersion <> 0 then
    raise Exception.Create('Unsupported version of attribute info message');

  // read flags
  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  if (FFlags and 1) <> 0 then
    FMaximumCreationIndex := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'maximum creation index'{$ENDIF});

  FFractalHeapAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'fractal heap address'{$ENDIF});
  FAttributeNameBTreeAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'attribute name B-tree address'{$ENDIF});

  if (FFlags and 2) <> 0 then
    FAttributeOrderBTreeAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'attribute order B-tree address'{$ENDIF});
end;


{ THdfCustomBlock }

constructor THdfCustomBlock.Create(SuperBlock: THdfSuperBlock;
  FractalHeap: THdfFractalHeap; DataObject: THdfDataObject);
begin
  FSuperBlock := SuperBlock;
  FFractalHeap := FractalHeap;
  FDataObject := DataObject;
end;

procedure THdfCustomBlock.LoadFromStream(Stream: TStream);
begin
  // read signature
  FSignature := Stream.ReadTextExcept(4{$IFDEF Debug}, 'signature'{$ENDIF});
  if FSignature <> GetSignature then
    raise Exception.Create(Format('Wrong signature (%s)', [string(FSignature)]));

  // read version
  FVersion := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'version'{$ENDIF});
  if FVersion <> 0 then
    raise Exception.Create('Unsupported version of link info message');

  // read heap header address
  FHeapHeaderAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'heap header address'{$ENDIF});

  // read block offset
  FBlockOffset := 0;
  FBlockOffset := Stream.ReadIntegerExcept((FFractalHeap.MaximumHeapSize + 7) div 8{$IFDEF DEBUG}, 'block offset'{$ENDIF});
end;

procedure THdfCustomBlock.SaveToStream(Stream: TStream);
begin
  raise Exception.Create('Not yet implemented');
end;


{ THdfDirectBlock }

class function THdfDirectBlock.GetSignature: THdfSignature;
begin
  Result := 'FHDB';
end;

procedure THdfDirectBlock.LoadFromStream(Stream: TStream);
var
  OffsetSize, LengthSize: Integer; // was Int64
  TypeAndVersion: Integer; // was Byte
  OffsetX, LengthX: Integer; // was Int64
  Name, Value: String;
  Attribute: THdfAttribute;
  HeapHeaderAddress: Integer; // was Int64
  StreamPos: Integer; // was Int64
  SubDataObject: THdfDataObject;
begin
  inherited LoadFromStream(Stream);

  if (FFractalHeap.Flags and 2) <> 0 then
    FChecksum := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'checksum'{$ENDIF});

  OffsetSize := Ceil(log2(FFractalHeap.MaximumHeapSize) / 8);
  if (FFractalHeap.MaximumDirectBlockSize < FFractalHeap.MaximumSize) then
    LengthSize := Ceil(log2(FFractalHeap.MaximumDirectBlockSize) / 8)
  else
    LengthSize := Ceil(log2(FFractalHeap.MaximumSize) / 8);

  repeat
    TypeAndVersion := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'type and version'{$ENDIF});

    OffsetX := 0;
    LengthX := 0;
    OffsetX := Stream.ReadIntegerExcept(OffsetSize{$IFDEF DEBUG}, 'offset'{$ENDIF});
    LengthX := Stream.ReadIntegerExcept(LengthSize{$IFDEF DEBUG}, 'length'{$ENDIF});

    if (TypeAndVersion = 3) then
    begin
      var Temp := 0;
      Temp := Stream.ReadIntegerExcept(5{$IFDEF DEBUG}, 'magic'{$ENDIF});
      if Temp <> $40008 then
        raise Exception.Create('Unsupported values');

      Name := Stream.ReadTextExcept(LengthX{$IFDEF Debug}, 'name'{$ENDIF});

      Temp := 0;
      Temp := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'magic'{$ENDIF});
      if (Temp <> $13) then
        raise Exception.Create('Unsupported values');

      LengthX := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'length'{$ENDIF});
      var ValueType := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'unknown value'{$ENDIF});
      var TypeExtend := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'unknown value'{$ENDIF});
      if (ValueType = $20000) then
        if (TypeExtend = 0) then
          Value := Stream.ReadTextExcept(LengthX{$IFDEF Debug}, 'value'{$ENDIF})
        else if (TypeExtend = 200) then
          Value := '';

      Attribute := THdfAttribute.Create(Name);
      Attribute.ValueAsString := Value;

      FDataObject.AddAttribute(Attribute);
    end
    else
    if (TypeAndVersion = 1) then
    begin
      var Temp := 0;
      Temp := Stream.ReadIntegerExcept(6{$IFDEF DEBUG}, 'magic'{$ENDIF});
      if Temp <> 0 then
        raise Exception.Create('FHDB type 1 unsupported values');

      // read name  
      LengthX := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'length'{$ENDIF});
      Name := Stream.ReadTextExcept(LengthX{$IFDEF Debug}, 'name'{$ENDIF});

      // read heap header address
      HeapHeaderAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'heap header address'{$ENDIF});

      StreamPos := Stream.Position;
      
      Stream.Position := HeapHeaderAddress;

      SubDataObject := THdfDataObject.Create(SuperBlock, Name);
      SubDataObject.LoadFromStream(Stream);

      FDataObject.AddDataObject(SubDataObject);

      Stream.Position := StreamPos;
    end;
  until TypeAndVersion = 0;
end;


{ THdfIndirectBlock }

constructor THdfIndirectBlock.Create(SuperBlock: THdfSuperBlock;
  FractalHeap: THdfFractalHeap; DataObject: THdfDataObject);
begin
  inherited Create(SuperBlock, FractalHeap, DataObject);

  FInitialBlockSize := FractalHeap.StartingBlockSize;
end;

class function THdfIndirectBlock.GetSignature: THdfSignature;
begin
  Result := 'FHIB';
end;

procedure THdfIndirectBlock.LoadFromStream(Stream: TStream);
var
  RowsCount: Integer;
  k, n: Integer;
  ChildBlockAddress: Integer; // was Int64
  SizeOfFilteredDirectBlock: Integer; // was Int64
  FilterMaskForDirectBlock: Integer;
  StreamPosition: Integer; // was Int64
  Block: THdfCustomBlock;
begin
  inherited LoadFromStream(Stream);

  if FBlockOffset <> 0 then
    raise Exception.Create('Only a block offset of 0 is supported so far');

  // The number of rows of blocks, nrows, in an indirect block of size iblock_size is given by the following expression:
  RowsCount := Round(log2(FInitialBlockSize) - log2(FFractalHeap.StartingBlockSize)) + 1;

  // The maximum number of rows of direct blocks, max_dblock_rows, in any indirect block of a fractal heap is given by the following expression: */
  FMaximumNumberOfDirectBlockRows := Round(log2(FFractalHeap.MaximumDirectBlockSize)
      - log2(FFractalHeap.StartingBlockSize)) + 2;

  // Using the computed values for nrows and max_dblock_rows, along with the Width of the doubling table, the number of direct and indirect block entries (K and N in the indirect block description, below) in an indirect block can be computed:
  if (RowsCount < FMaximumNumberOfDirectBlockRows) then
    k := RowsCount * FFractalHeap.TableWidth
  else
    k := FMaximumNumberOfDirectBlockRows * FFractalHeap.TableWidth;

  // If nrows is less than or equal to max_dblock_rows, N is 0. Otherwise, N is simply computed:
  n := k - (FMaximumNumberOfDirectBlockRows * FFractalHeap.TableWidth);

  while (k > 0) do
  begin
    ChildBlockAddress := 0;
    ChildBlockAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'child direct block address'{$ENDIF});
    if (FFractalHeap.EncodedLength > 0) then
    begin
      SizeOfFilteredDirectBlock := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'filtered direct block'{$ENDIF});
      FilterMaskForDirectBlock := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'filter mask'{$ENDIF});
    end;

    if (ChildBlockAddress > 0) and (ChildBlockAddress < SuperBlock.EndOfFileAddress) then
    begin
      StreamPosition := Stream.Position;
      Stream.Position := ChildBlockAddress;

      Block := THdfDirectBlock.Create(SuperBlock, FFractalHeap, FDataObject);
      Block.LoadFromStream(Stream);

      Stream.Position := StreamPosition;
    end;
    Dec(k);
  end;

  while (n > 0) do
  begin
    ChildBlockAddress := 0;
    ChildBlockAddress := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'child direct block address'{$ENDIF});

    if (ChildBlockAddress > 0) and (ChildBlockAddress < SuperBlock.EndOfFileAddress) then
    begin
      StreamPosition := Stream.Position;
      Stream.Position := ChildBlockAddress;

      Block := THdfInDirectBlock.Create(SuperBlock, FFractalHeap, FDataObject);
      Block.LoadFromStream(Stream);

      Stream.Position := StreamPosition;
    end;
    Dec(n);
  end;
end;


{ THdfFractalHeap }

constructor THdfFractalHeap.Create(SuperBlock: THdfSuperBlock; DataObject: THdfDataObject);
begin
  FSuperBlock := SuperBlock;
  FDataObject := DataObject;
end;

procedure THdfFractalHeap.LoadFromStream(Stream: TStream);
var
  Block: THdfCustomBlock;
begin
  // read signature
  FSignature := Stream.ReadTextExcept(4{$IFDEF Debug}, 'signature'{$ENDIF});
  if FSignature <> 'FRHP' then
    raise Exception.Create(Format('Wrong signature (%s)', [string(FSignature)]));

  // read version
  FVersion := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'version'{$ENDIF});
  if FVersion <> 0 then
    raise Exception.Create('Unsupported version of link info message');

  FHeapIdLength := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'heap ID length'{$ENDIF});
  FEncodedLength := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'I/O filters'' encoded length'{$ENDIF});
  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  FMaximumSize := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'maximum size'{$ENDIF});
  FNextHugeID := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'next huge ID'{$ENDIF});
  FBtreeAddresses := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'Btree Addresses'{$ENDIF});
  FAmountFreeSpace := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'amount of free space'{$ENDIF});
  FAddressManagedBlock := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'offset size'{$ENDIF});
  FAmountManagedSpace := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'amount of managed space'{$ENDIF});
  FAmountAllocatedManagedSpace := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'amount of allocated managed space'{$ENDIF});
  FOffsetDirectBlockAllocation := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'offset of direct block allocation'{$ENDIF});
  FNumberOfManagedObjects := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'number of managed object'{$ENDIF});
  FSizeOfHugeObjects := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'size of huge objects'{$ENDIF});
  FNumberOfHugeObjects := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'number of huge objects'{$ENDIF});
  FSizeOfTinyObjects := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'size of tiny objects'{$ENDIF});
  FNumberOfTinyObjects := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'number of tiny objects'{$ENDIF});
  FTableWidth := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'table width'{$ENDIF});
  FStartingBlockSize := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'starting block size'{$ENDIF});
  FMaximumDirectBlockSize := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'maximum direct block size'{$ENDIF});
  FMaximumHeapSize := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'maximum heap size'{$ENDIF});
  FStartingNumber := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'starting number'{$ENDIF});
  FAddressOfRootBlock := Stream.ReadIntegerExcept(SuperBlock.OffsetSize{$IFDEF DEBUG}, 'address of root block'{$ENDIF});
  FCurrentNumberOfRows := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'current number of rows'{$ENDIF});
  if FEncodedLength > 0 then
  begin
    FSizeOfFilteredRootDirectBlock := Stream.ReadIntegerExcept(SuperBlock.LengthsSize{$IFDEF DEBUG}, 'the size of filtered root direct blocks'{$ENDIF});
    FIOFilterMask := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'I/O filter mask'{$ENDIF});
  end;

  if (FNumberOfHugeObjects > 0) then
    raise Exception.Create('Cannot handle huge objects');

  if (FNumberOfTinyObjects > 0) then
    raise Exception.Create('Cannot handle tiny objects');

  if (FAddressOfRootBlock > 0) and (FAddressOfRootBlock < Superblock.EndOfFileAddress) then
  begin
    Stream.Position := FAddressOfRootBlock;

    if FCurrentNumberOfRows <> 0 then
      Block := THdfIndirectBlock.Create(SuperBlock, Self, FDataObject)
    else
      Block := THdfDirectBlock.Create(SuperBlock, Self, FDataObject);
    Block.LoadFromStream(Stream);
  end;
end;

procedure THdfFractalHeap.SaveToStream(Stream: TStream);
begin
  raise Exception.Create('Not yet implemented');
end;


{ THdfDataObject }

constructor THdfDataObject.Create(SuperBlock: THdfSuperBlock);
begin
  FSuperblock := SuperBlock;
  FName := '';

  // create a few default messages
  FDataType := THdfMessageDataType.Create(FSuperBlock, Self);
  FDataSpace := THdfMessageDataSpace.Create(FSuperBlock, Self);
  FLinkInfo := THdfMessageLinkInfo.Create(FSuperBlock, Self);
  FGroupInfo := THdfMessageGroupInfo.Create(FSuperBlock, Self);
  FAttributeInfo := THdfMessageAttributeInfo.Create(FSuperBlock, Self);

  FAttributesHeap := THdfFractalHeap.Create(FSuperBlock, Self);
  FObjectsHeap := THdfFractalHeap.Create(FSuperBlock, Self);
end;

procedure THdfDataObject.AddAttribute(Attribute: THdfAttribute);
begin
  FAttributeList.Add(Attribute);
end;

procedure THdfDataObject.AddDataObject(DataObject: THdfDataObject);
begin
  FDataObjects.Add(DataObject);
end;

constructor THdfDataObject.Create(SuperBlock: THdfSuperBlock; Name: String);
begin
  Create(SuperBlock);
  FName := Name;
end;

function THdfDataObject.GetAttributeListCount: Integer;
begin
  Result := FAttributeList.Count;
end;

function THdfDataObject.GetAttributeListItem(Index: Integer): THdfAttribute;
begin
  if (Index < 0) or (Index >= FAttributeList.Count) then
    raise Exception.Create(Format('Index out of bounds (%d)', [Index]));

  Result := THdfAttribute(FAttributeList[Index]);
end;

function THdfDataObject.GetDataLayoutChunk(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= Length(FDataLayoutChunk)) then
    raise Exception.Create(Format('Index out of bounds (%d)', [Index]));

  Result := FDataLayoutChunk[Index];
end;

function THdfDataObject.GetDataLayoutChunkCount: Integer;
begin
  Result := Length(FDataLayoutChunk);
end;

function THdfDataObject.GetDataObject(Index: Integer): THdfDataObject;
begin
  if (Index < 0) or (Index >= FDataObjects.Count) then
    raise Exception.Create(Format('Index out of bounds (%d)', [Index]));

  Result := THdfDataObject(FDataObjects[Index]);
end;

function THdfDataObject.GetDataObjectCount: Integer;
begin
  Result := FDataObjects.Count;
end;

function THdfDataObject.HasAttribute(Name: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 0 to AttributeListCount - 1 do
    if string(AttributeListItem[Index].Name) = Name then
      Exit(True);
end;

function THdfDataObject.GetAttribute(Name: string): string;
var
  Index: Integer;
begin
  Result := '';
  for Index := 0 to AttributeListCount - 1 do
    if string(AttributeListItem[Index].Name) = Name then
      Exit(string(AttributeListItem[Index].ValueAsString));
end;

procedure THdfDataObject.LoadFromStream(Stream: TStream);
begin
  FSignature := Stream.ReadTextExcept(4{$IFDEF Debug}, 'signature'{$ENDIF});
  if FSignature <> 'OHDR' then
    raise Exception.Create(Format('Wrong signature (%s)', [string(FSignature)]));

  // read version
  FVersion := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'version'{$ENDIF});
  if FVersion <> 2 then
    raise Exception.Create('Invalid verion');

  FFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'flags'{$ENDIF});

  // eventually read time stamps
  if (FFlags and (1 shl 5)) <> 0 then
  begin
    FAccessTime := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'access time'{$ENDIF});
    FModificationTime := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'modification time'{$ENDIF});
    FChangeTime := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'change time'{$ENDIF});
    FBirthTime := Stream.ReadIntegerExcept(4{$IFDEF DEBUG}, 'birth time'{$ENDIF});
  end;

  // eventually skip number of attributes
  if (FFlags and (1 shl 4)) <> 0 then
  begin
    FMaximumCompact := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'maximum number of compact attributes'{$ENDIF});
    FMinimumDense := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'minimum number of dense attributes'{$ENDIF});
  end;

  FChunkSize := Stream.ReadIntegerExcept(1 shl (FFlags and 3){$IFDEF DEBUG}, 'chunk size'{$ENDIF});

  ReadObjectHeaderMessages(Stream, Stream.Position + FChunkSize);

  // parse message attribute info
  if (AttributeInfo.FractalHeapAddress > 0) and
     (AttributeInfo.FractalHeapAddress < FSuperblock.EndOfFileAddress) then
  begin
    Stream.Position := AttributeInfo.FractalHeapAddress;
    FAttributesHeap.LoadFromStream(Stream);
  end;

  // parse message link info
  if (LinkInfo.FractalHeapAddress > 0) and
     (LinkInfo.FractalHeapAddress < FSuperblock.EndOfFileAddress) then
  begin
    Stream.Position := LinkInfo.FractalHeapAddress;
    FObjectsHeap.LoadFromStream(Stream);
  end;
end;

procedure THdfDataObject.SaveToStream(Stream: TStream);
begin
  raise Exception.Create('Not yet implemented');
end;

procedure THdfDataObject.ReadObjectHeaderMessages(Stream: TStream; EndOfStream: Integer);
var
  MessageType: Integer; // was Byte
  MessageSize: Integer; // was Word
  MessageFlags: Integer; // was Byte
  EndPos: Integer; // was Int64
  DataObjectMessage: THdfDataObjectMessage;
begin
  while Stream.Position < EndOfStream - 4 do
  begin
    MessageType := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'message type'{$ENDIF});
    MessageSize := Stream.ReadIntegerExcept(2{$IFDEF DEBUG}, 'message size'{$ENDIF});
    MessageFlags := Stream.ReadIntegerExcept(1{$IFDEF DEBUG}, 'message flags'{$ENDIF});

    if (MessageFlags and not 5) <> 0 then
      raise Exception.Create('Unsupported OHDR message flag');

    // eventually skip creation order
    if FFlags and (1 shl 2) <> 0 then
      Stream.Seek(2, True);

    EndPos := Stream.Position + MessageSize;

    DataObjectMessage := nil;
    case MessageType of
      0:
        Stream.Seek(MessageSize, True);
      1:
        DataObjectMessage := FDataSpace;
      2:
        DataObjectMessage := FLinkInfo;
      3:
        DataObjectMessage := FDataType;
      5:
        DataObjectMessage := THdfMessageDataFill.Create(FSuperBlock, Self);
      8:
        DataObjectMessage := THdfMessageDataLayout.Create(FSuperBlock, Self);
      10:
        DataObjectMessage := FGroupInfo;
      11:
        DataObjectMessage := THdfMessageFilterPipeline.Create(FSuperBlock, Self);
      12:
        DataObjectMessage := THdfMessageAttribute.Create(FSuperBlock, Self);
      16:
        DataObjectMessage := THdfMessageHeaderContinuation.Create(FSuperBlock, Self);
      21:
        DataObjectMessage := FAttributeInfo;
      else
        raise Exception.Create(Format('Unknown header message (%d)', [MessageType]));
    end;

    // now eventally load data object message
    if Assigned(DataObjectMessage) then
      DataObjectMessage.LoadFromStream(Stream);

    {$IFDEF IgnoreWrongPosition}
    Stream.Position := EndPos;
    {$ELSE}
    if Stream.Position <> EndPos then
      Assert(Stream.Position = EndPos);
    {$ENDIF}
  end;
end;


{ THdfFile }

constructor THdfFile.Create;
begin
  inherited Create;

  FSuperBlock := THdfSuperBlock.Create;
  FDataObject := THdfDataObject.Create(FSuperblock);
end;

function THdfFile.GetAttribute(Name: string): string;
begin
  Result := FDataObject.GetAttribute(Name);
end;

function THdfFile.HasAttribute(Name: string): Boolean;
begin
  Result := FDataObject.HasAttribute(Name);
end;

procedure THdfFile.LoadFromStream(Stream: TStream);
begin
  FSuperblock.LoadFromStream(Stream);
  FDataObject.LoadFromStream(Stream);
end;

procedure THdfFile.SaveToStream(Stream: TStream);
begin
  raise Exception.Create('Not yet implemented');
end;

procedure THdfFile.LoadFromBuffer(Buffer: JArrayBuffer);
begin
  LoadFromStream(TStream.Create(Buffer));
end;

procedure THdfFile.SaveToBuffer(Buffer: JArrayBuffer);
begin
  SaveToStream(TStream.Create(Buffer));
end;

end.