//+------------------------------------------------------------------+
//|                                                 CurrencyInfo.mq5 |
//|                                                    Akimasa Ohara |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Akimasa Ohara"
#property link      "https://www.mql5.com"
#property version   "1.00"

// EA起動時にランダムなIDを発行
int ProcessID = 
int fileHandle;  // ファイルハンドル
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//
  
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
  bool exitInputFile = 
  
  // ファイルを開く
  fileHandle = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_CSV); 
  
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
   
   // 最終入力の日にちと時間を取得
   
   // プラットフォーム時間に修正　サマータイム注意
   
  }else{
  
   //ヘッダーを挿入
  
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
   Print(fileHandle + " , FILECLOSE , OK");
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