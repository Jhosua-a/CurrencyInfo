//+------------------------------------------------------------------+
//|                                                 CurrencyInfo.mq5 |
//|                                                    Akimasa Ohara |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Akimasa Ohara"
#property link      "https://www.mql5.com"
#property version   "1.00"

input bool IsUK = false; // サマータイム判定時に利用(初期値oanda)

int ProcessID; //システム起動時にランダムなIDを振られる

MqlDateTime FileLastDateStr;

//　一日の始まりにサマータイムか確認する
bool DST;


int fileHandle;  // ファイルハンドル
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//
  // EA起動時にランダムなIDを発行
  MathSrand(GetTickCount());
  ProcessID = MathRand();
  
  // チャートウィンドウの銘柄名を取得
  string symbolName = Symbol();
  // チャートウィンドウの時間軸を取得 
  string TimeFrame = getTimeFrameName();
  
  // 想定にないチャート時間軸の場合は処理を終了する
  if(TimeFrame == ""){
   Alert("時間軸を取得できませんでした");
   return(INIT_FAILED);
  }
  
  //　ファイル名を生成
  string fileName = symbolName + TimeFrame +".csv"; 
  
  // 実行ファイルが存在するかを保存
  bool exitInputFile = FileIsExist(fileName,0);
  
  // ファイルを開く
  fileHandle = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_CSV, ","); 
  
  // ファイルオープン時にエラーが起きた場合、メッセージとエラーコードの出力
  if(fileHandle < 0){
    Print(ProcessID , " ," ,fileHandle ," FILEOPEN , NG");
    Alert("Error opening file");
    return(INIT_FAILED);
  }
  
  Print(fileHandle , " , FILEOPEN , OK");
   
  //実行ファイルが存在するか
  if(exitInputFile == true){
   // 実行ファイルから最終行を取得
   FileSeek(fileHandle,0,SEEK_END);
   //　最終行1行の文字列取得
   string strCandle = FileReadString(fileHandle);
   string CandleInfo[];
   // 配列形式に文字列を分割
   int result = StringSplit(strCandle, StringGetCharacter(",",0),CandleInfo ); // 戻り値：カラムの数、NULL(0)、エラー(1)
   
   // 最終入力の日にちと時間を取得
   TimeToStruct(StringToTime(CandleInfo[0]),FileLastDateStr);

   
   //// サマータイムかどうかの判定 onTickへ移動
   //MqlDateTime CurrentTime;
   //TimeCurrent(CurrenTime);
   //DST = IsDST(CurrentTime.year, CurrentTime.mon, CurrentTime.day, CurrentTime.day_of_week, IsUK)
   
   
  }else{
  
   //ヘッダーを挿入
   FileWrite(fileHandle,"SystemData, Date ,Time ,Time(Japan), Week ,Open ,Close ,High ,Low　,Volume");
  }
  
  
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   //  ファイルを閉じる
   FileClose(fileHandle);
   Print(IntegerToString(fileHandle) + " , FILECLOSE , OK");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  
//---
   
  }
//+------------------------------------------------------------------+

string getTimeFrameName(){ 
   switch(Period()){
      case(PERIOD_M1):return("M1");
      case(PERIOD_M5):return("M5");
      case(PERIOD_M10):return("M10");
      case(PERIOD_M15):return("M15");
      case(PERIOD_M20):return("M20");
      case(PERIOD_M30):return("M30");
      case(PERIOD_H1):return("H1");
      case(PERIOD_H4):return("H4");
      case(PERIOD_H12):return("H12");
      case(PERIOD_D1):return("D1");
      case(PERIOD_W1):return("W1");
      default:return("");
   }
   
}

bool IsDST(int year, int mon, int day, int week){
   datetime StartDate, EndDate;
   
   bool dst;
   
   string strYear = IntegerToString(year);
   string strMon = IntegerToString(mon);
   string strDay = IntegerToString(day);
   datetime CurrentDay = StringToTime(strYear + "." + strMon + "." + strDay);
   
   MqlDateTime strSD, strED;

   // 2007以降米国式
   if(!IsUK && year >= 2007){
      TimeToStruct(StringToTime(strYear + ".3.14"),strSD);
      StartDate = StringToTime(strYear + ".3." + (string)(14 - strSD.day_of_week));
      TimeToStruct(StringToTime(strYear + ".11.7"),strED);
      EndDate = StringToTime(strYear + ".11." + (string)(7 - strSD.day_of_week));
      
   }else{
      // 英国式
      if(IsUK){
         TimeToStruct(StringToTime(strYear + ".3.31"),strSD);
         StartDate = StringToTime(strYear + ".3." + (string)(31 - strSD.day_of_week));
      // 2006以前の米国式
      }else{
         TimeToStruct(StringToTime(strYear + ".4.7"),strSD);
         StartDate = StringToTime(strYear + ".4." + (string)(7 - strSD.day_of_week));
      }

      TimeToStruct(StringToTime(strYear + ".10.31"),strED);
      EndDate = StringToTime(strYear + ".10." + (string)(31 - strSD.day_of_week));
   }

   // サマータイム判定
   if(CurrentDay >= StartDate && CurrentDay < EndDate) dst = true;
   else dst = false;

   return(dst);
}


int PFTimetoJapanTime(int PFTime){
   int JapanTime;
   
   if(DST){
      JapanTime = PFTime + 7;
   }else{
      JapanTime = PFTime + 6;
   }
   
   return(JapanTime);
}

