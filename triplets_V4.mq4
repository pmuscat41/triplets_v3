//+------------------------------------------------------------------+

//|                                                pairs trading.mq4 |

//|                        Copyright 2022, MetaQuotes Software Corp. |

//|                                             https://www.mql5.com |

//+------------------------------------------------------------------+



#property copyright "Copyright 2023, Paul Muscat."
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

static double hedge_Ratio, order_size, OrderScaling, band_Factor, Meantime,hedge_Ratio2, order_size2 ;

//note Meantime is a double - can de half days,,, 

static string  Sec_a,Sec_b,Sec_c,D;
static int lookback;
static int      inpMagicNumber;
string post;
static string            Sec_name;
static string      inpTradeComments;
enum IG_ENUM_SYMBOLS {
      GBP_USD_EUR=1,
      CAD_USD_EUR=2,
      NZD_USD_EUR=3,
      REMOVE_EA=13};

static input  IG_ENUM_SYMBOLS inpSimb=              GBP_USD_EUR;//Choose security to trade
static input bool buySpread=                     False;// Buy Spread immediately
static input bool sellSpread=                    False;//Sell Spread immediately
static input ENUM_TIMEFRAMES timeFrame=          PERIOD_D1;//  timeframe to trade
bool  input closeIt=                             False;// Close the Pair Trade
bool  input LiveTrade=                           True;// is this live trading? (select False for backtest)
int   input LB=                                    0;// Optimize Lookback
double input BF=                                   0;// Optimize Band Factor to enter trade (deviation)
double input OS   =                                0;// optimize order scaling
static int counter;
static datetime linestart;
static datetime lineend;
 enum ENUM_CONDITION {  WAITING,INALONG,INASHORT};
static ENUM_CONDITION Status=WAITING;
// Array
static double spread_;
static double SecA_;
static double SecB_;
static double SecC_;
static int      sec_a_price=0;
static int      sec_b_price=1;
static int      spread=2;
static int      ma=3;
static int      std_dev=4;
static int      upper_b=5;
static int      lower_b=6;
static int       sec_c_price=7;
static double   df[8,5000];
static int ord1=0;
static int ord2=0;
static int ord3=0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

//---

 // Exit the Trade
if (closeIt) CloseAllDeals ();
// SECURITIES FOR IG
//if (AccountCompany ()=="IG Group Limited" && ord1==0 && ord2==0) 
//{

switch (inpSimb)
{
case 1:
inpMagicNumber=1101;	   D="GBP/USD/EUR";	Sec_a="GBPUSD.d";	   Sec_b= "EURGBP.d"; Sec_c ="EURUSD.d";	hedge_Ratio= 1.390392908274614; 
hedge_Ratio2= 1.286692326438779;	order_size=  1.41; order_size2= 1.15; lookback=7;	band_Factor=0.75; OrderScaling=	0.3;      break;

case 2:
inpMagicNumber=1102;	   D="CAD/USD/EUR";	Sec_a="USDCAD";	   Sec_b= "EURUSD"; Sec_c ="EURCAD";	hedge_Ratio= 1.2344337296219672;
 hedge_Ratio2= -0.9136524490829343;	order_size=  1.23; order_size2= 0.91; lookback=18;	band_Factor=1; OrderScaling=	0.3;      break; 

case 3:
inpMagicNumber=1103;	   D="NZD/USD/EUR";	Sec_a="NZDUSD.d";	   Sec_b= "EURNZD.d"; Sec_c ="EURUSD.d";	hedge_Ratio= 0.3616916468797127;
 hedge_Ratio2= 0.5787533097996576;	order_size=  0.36; order_size2= 0.58; lookback=7;	band_Factor=0.75; OrderScaling=	0.3;      break;

}
//}

if (!LiveTrade)
   {  lookback=LB ;	
     band_Factor=BF; 
    OrderScaling=	OS;}

//if (AccountCompany ()!="IG Group Limited")  return (INIT_FAILED);

Sec_name=   D;
inpTradeComments     = "triplets_v3";
Comment (" ");
post=" ";
post+="\n Description=   "+  D;
post+="\n Magic number= " +inpMagicNumber;
post+="\n";
post+="\n Sec_a=  "+ Sec_a;
post+="\n Sec_b= "+ Sec_b;
post+="\n Sec_c= "+ Sec_c;
post+="\n Mean time to revert =  "+ Meantime  ;
post+="\n Order scaling=  "+  OrderScaling;
post+="\n Standard deviation to enter =  "+ band_Factor;
post+="\n Lookback=  "+ lookback;
post+="\n Dedge_ratio (2 decimal)=  "+ order_size;
post+="\n Hedge Ratio=  "+ hedge_Ratio;

 for (int p=0;p<lookback;p++)
   {

   df[sec_a_price,p]=iClose(Sec_a,timeFrame,1+lookback-p);
   df[sec_b_price,p]=iClose(Sec_b,timeFrame,1+lookback-p);
   df[sec_c_price,p]=iClose(Sec_c,timeFrame,1+lookback-p);
   df[spread,p]= iClose(Sec_a,timeFrame,1+lookback-p)+(iClose(Sec_b,timeFrame,1+lookback-p)*hedge_Ratio)+ (iClose(Sec_c,timeFrame,1+lookback-p)*hedge_Ratio2);    
  
   }

 
Update_Df (lookback);
counter=lookback;
if (buySpread== True)LongEntry();
if (sellSpread==True)ShortEntry();
if (buySpread==false && sellSpread== false) CheckPositions();
Comment (" ");
Comment (post);

//---

   return(INIT_SUCCEEDED);

  }

//+------------------------------------------------------------------+

//| Expert deinitialization function                                 |

//+------------------------------------------------------------------+

void OnDeinit(const int reason)

  {

//---

   

  }

//+------------------------------------------------------------------+

//| Expert tick function                                             |

//+------------------------------------------------------------------+

void OnTick()

  {

SecA_=iClose(Sec_a,timeFrame,0);
SecB_=iClose(Sec_b,timeFrame,0);
SecC_=iClose(Sec_c,timeFrame,0);
spread_= iClose(Sec_a,timeFrame,0)+iClose(Sec_b,timeFrame,0)*hedge_Ratio+iClose(Sec_c,timeFrame,0)*hedge_Ratio2;   
////////////////////////////////////////////////////////////////
if (!newBar()) return;  //only trade on new bar
Comment (post);
counter++;
// update DataFile
 Update_Df (counter);
 //
 // alternative strat- buy down day sell up day
 //(df[spread,counter-1]< df[spread,counter])
 //(df[spread,counter-1]>df[spread,counter])

if (     (spread_ < df[lower_b,counter]) && (Status==WAITING))
   {

      LongEntry();
   }


if ( (spread_>df[upper_b,counter]) && (Status==WAITING))

   {

      ShortEntry();

   }
 
if (Status==INASHORT)   CheckShortExit ();
if (Status==INALONG)   CheckLongExit ();
CheckEntry ();
if (buySpread==false && sellSpread== false) CheckPositions();
  }

//+------------------------------------------------------------------+



void LongEntry ()

{
post+="\n  Long Entry called try and buy- "+D;
ord1=-1;
ord2=-1;
ord3=-1;
if (LiveTrade || Symbol()== Sec_a )
ord1= orderExecute (ORDER_TYPE_BUY,Sec_a,0,0,OrderScaling, inpTradeComments, inpMagicNumber);
if (LiveTrade || Symbol()== Sec_b )
   
   if (hedge_Ratio >0)

      ord2= orderExecute (ORDER_TYPE_BUY,Sec_b,0,0, order_size*OrderScaling, inpTradeComments,inpMagicNumber);

   else

      ord2= orderExecute (ORDER_TYPE_SELL,Sec_b,0,0, order_size*OrderScaling, inpTradeComments,inpMagicNumber);



if (LiveTrade || Symbol()== Sec_c )

   if (hedge_Ratio2 >0)

      ord3= orderExecute (ORDER_TYPE_BUY,Sec_c,0,0, order_size2*OrderScaling, inpTradeComments,inpMagicNumber);

   else

      ord3= orderExecute (ORDER_TYPE_SELL,Sec_c,0,0, order_size2*OrderScaling, inpTradeComments,inpMagicNumber);



if (ord1>0 || ord2>0 || ord3>0 ) {Status=INALONG;return;}



}





void ShortEntry () 

{

ord1=-1;

ord2=-1;

ord3=-1;

post+="\nShort Entry called  try and sell- "+D;



if (LiveTrade || Symbol()== Sec_a )

ord1= orderExecute (ORDER_TYPE_SELL,Sec_a,0,0,OrderScaling, inpTradeComments, inpMagicNumber);



if (LiveTrade  || Symbol()== Sec_b )

   if (hedge_Ratio2 >0)

      ord2= orderExecute (ORDER_TYPE_SELL,Sec_b,0,0,order_size*OrderScaling, inpTradeComments, inpMagicNumber);

   else

      ord2= orderExecute (ORDER_TYPE_BUY,Sec_b,0,0,order_size*OrderScaling, inpTradeComments, inpMagicNumber);



if (LiveTrade  || Symbol()== Sec_c )

   if (hedge_Ratio2 >0)

      ord3= orderExecute (ORDER_TYPE_SELL,Sec_c,0,0,order_size2*OrderScaling, inpTradeComments, inpMagicNumber);

   else

      ord3= orderExecute (ORDER_TYPE_BUY,Sec_c,0,0,order_size2*OrderScaling, inpTradeComments, inpMagicNumber);



if (ord2>0 || ord1>0|| ord3>0 ) {Status=INASHORT;return;}

}





void CheckShortExit ()

{int cntr=0;



post+="\n lCheck Short Exit called - "+D;

if (spread_ < df[ma,counter])

   {



      post+="\nl==========================short exit signal========================";

      CloseAllDeals();

   

   }

}



void CheckLongExit ()

{

post+="\n Check Long Exit called-  "+D;



if (spread_> df[ma,counter])

   {



   post+="\n---------------Long exit signal===========================";

   CloseAllDeals();

   }

}







// fill values of df



void Update_Df (int c)

{

double StdDev;
double rolling;
double MA;
double variance;
double Sd;
// update prices and spread
df[sec_a_price,c]=iClose(Sec_a,timeFrame,1);
df[sec_b_price,c]=iClose(Sec_b,timeFrame,1);
df[sec_c_price,c]=iClose(Sec_c,timeFrame,1);
df[spread,c]= iClose(Sec_a,timeFrame,0)+iClose(Sec_b,timeFrame,0)*hedge_Ratio+iClose(Sec_c,timeFrame,0)*hedge_Ratio2; 
// calculate ma
rolling=0;
for (int m=0;m<lookback;m++)
{

rolling= rolling+ df[spread,c-m];

}



 MA=rolling/lookback;
df[ma,c]=MA;

// calculate std dev

//step1 - variances

variance=0;

for (int v=0; v<lookback; v++)

{

variance= variance+((df[spread,c-v]-MA)*(df[spread,c-v]-MA));


}

Sd= (variance/lookback);

StdDev=MathSqrt( Sd);

df[std_dev,c]=StdDev;


// calculate upper bb

df[upper_b,c]=MA+ (StdDev*band_Factor);

// calculate lower bb


df[lower_b,c]=MA-(StdDev*band_Factor);


return;

}





  //simple function to open a new order 

   

   int orderExecute (ENUM_ORDER_TYPE orderType, string SMBL ,double stopLoss, double takeProfit,double  inpOrderSize,string  inpTradeComments,int  inpMagicNumber )

   

   

   {

      

      int   ticket=-1;

      double openPrice;

      double stopLossPrice;

      double takeProfitPrice;

      

      // caclulate the open price, take profit and stoploss price based on the order type

      //

      

    double newlevel;

    double StopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);

    double freezeLevel = MarketInfo(Symbol(), MODE_FREEZELEVEL);

    

  





 int count = 0;

            while ((ticket == -1) && (count < 10))

      

 {  

      Print ("retrying to enter  "+D+ "  - Ask = "+Ask+ "  Bid= " +Bid);

      

      if (orderType==ORDER_TYPE_BUY){

      

      

      

      

         

         RefreshRates();

         openPrice    = NormalizeDouble(SymbolInfoDouble(SMBL, SYMBOL_ASK), Digits());

      

         //Ternary operator, because it makes things look neat

         //   if stopLoss==0.0){

     

         //stopLosssPrice = 0.0} 

         //   else {

         //    stopLossPrice = NormalizedDouble (openPrice - stopLoss, Digist());

         //

      

         stopLossPrice = (stopLoss==0.0)? 0.0: NormalizeDouble(openPrice-stopLoss,Digits());

         takeProfitPrice = (takeProfit==0.0)? 0.0: NormalizeDouble(openPrice+takeProfit,Digits());

      }else if (orderType==ORDER_TYPE_SELL){

         RefreshRates(); 

         openPrice = NormalizeDouble (SymbolInfoDouble(SMBL, SYMBOL_BID), Digits());

         stopLossPrice = (stopLoss==0.0)? 0.0: NormalizeDouble(openPrice+stopLoss,Digits());

         takeProfitPrice = (takeProfit==0.0)? 0.0: NormalizeDouble(openPrice-takeProfit,Digits());

      

      }else{ 

      // this function works with buy or sell

         return (-1);

      }

      

      ticket = OrderSend (SMBL, orderType,inpOrderSize, openPrice,10,0, 0,inpTradeComments, inpMagicNumber);

      

      Print ("Order Placed -  "+D+ "  -=-order type= "+orderType+ "Lots =   " + inpOrderSize+ "Open P =   "+ openPrice + "    SL = "+  stopLossPrice + "   TP =  " + takeProfitPrice+ 

      "Error!!=  "+GetLastError()+  "      Stoplevel ="+StopLevel*_Point+ "  Stoplos= "+ stopLoss+ " freeze level="+freezeLevel+ "  new sl= "+newlevel);

      

      Print ("Bid Price=  "+ Bid +"Ask Price= "+Ask);

      

      count++; 

      

  }    

      

      return (ticket);

      

      

}

     










void CheckEntry ()



{

 

 if ((spread_< df[lower_b,counter]) && (Status==WAITING))

   {

      LongEntry();

   }



if ((spread_>df[upper_b,counter]) && (Status==WAITING))

   {

      ShortEntry();

   }



}



void CheckPositions()



{

// function to check if there are open positions for this ea.

      for(int i=(OrdersTotal()-1); i>=0; i--)

      {

        if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)



          {

            post+="\nfalse result in the loop - loop=" + i + "Order lots=  " + OrderLots();

            return;

           }



         else

                      

         {  OrderSelect(i,SELECT_BY_POS,MODE_TRADES);

               if (OrderMagicNumber()== inpMagicNumber ||  OrderComment ()==  IntegerToString(inpMagicNumber))

              {

                        if (OrderType()==ORDER_TYPE_BUY && OrderSymbol()==Sec_a)             

                     {

                           ord1=OrderTicket ();

                           Status=INALONG;                               

                     }

               

               

               if (OrderType()==ORDER_TYPE_SELL && OrderSymbol()==Sec_a)

                     {

                        ord2=OrderTicket();

                        Status=INASHORT;

                     

                     }

               

               if (OrderType()==ORDER_TYPE_BUY && OrderSymbol()==Sec_b)             

                     {

                           ord1=OrderTicket ();

                           Status=INALONG;                     

                     }

               

               if (OrderType()==ORDER_TYPE_SELL && OrderSymbol()==Sec_b)

                     {

                        ord2=OrderTicket();

                        Status=INASHORT;

                     

                     }

               

               



               if (OrderType()==ORDER_TYPE_BUY && OrderSymbol()==Sec_c)             

                     {

                           ord3=OrderTicket ();

                           Status=INASHORT;                     

                     }

               

               if (OrderType()==ORDER_TYPE_SELL && OrderSymbol()==Sec_c)

                     {

                        ord3=OrderTicket();

                        Status=INALONG;

                     

                     }

               



               }  

         

         

          }

      

      }





               post +="\n";

               post+="\n Long Trade Order No. = "+ ord1;

               post+="\n Short Trade Order No. ="+ ord2;



}



void CloseAllDeals()

  

  

  {   int ticket2;

      Comment ("\nl close order");

      for(int i=(OrdersTotal()-1); i>=0; i--)



        {

         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)

            

             {

               Alert("Error" + D+" false result in the loop - loop=" + i + "Order lots=  " + OrderLots());

               return;

             }



         else

           {

            double askprice= MarketInfo(OrderSymbol(),MODE_ASK);

            double bidprice= MarketInfo(OrderSymbol(),MODE_BID);

            if(OrderMagicNumber()== inpMagicNumber ||  OrderComment ()== IntegerToString(inpMagicNumber))

               if (OrderType()==ORDER_TYPE_SELL)

                 {

                   ticket2= OrderClose(OrderTicket(),OrderLots(),askprice,3,Red);

                     int count = 0;

                        while((ticket2 == -1) && (count < 10))

                             {

                              RefreshRates();

                              ticket2= OrderClose(OrderTicket(),OrderLots(),askprice,3,Red);

                               count++;

                             }               

                   }





               if(OrderMagicNumber()== inpMagicNumber||  OrderComment ()==  IntegerToString(inpMagicNumber))

                  if (OrderType()==ORDER_TYPE_BUY)

                     {

                           ticket2= OrderClose(OrderTicket(),OrderLots(),bidprice,3,Red);

                           int count = 0;

                               while((ticket2 == -1) && (count < 10))

                             {

                              RefreshRates();

                              ticket2= OrderClose(OrderTicket(),OrderLots(),askprice,3,Red);

                               count++;

                             }

                 

                 

                       }



            if(ticket2>0)



                    { Status=WAITING;

                     ord1=0;

                      ord2=0;

                      ord3=0;

                      post="\n-------------------------- All orders closed";

                      Comment (post);

                      }

           

        }

     }

}



// true or false has bar changed

bool newBar(){

   datetime          currentTime =  iTime(Symbol(),PERIOD_D1,0);// get openong time of bar
   static datetime   priorTime =   currentTime; // initialized to prevent trading on first bar
   bool              result =      (currentTime!=priorTime); //Time has changed
   priorTime               =        currentTime; //reset for next time
   return(result);
   }

