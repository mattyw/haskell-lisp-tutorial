{-# LANGUAGE DeriveDataTypeable #-}
module M6 where

import Data.Typeable.Internal
import Text.ParserCombinators.Parsec
import Data.Maybe
import Data.Map
import Control.Exception
import Prelude hiding (lookup)

type Env = Map String Expression

data Expression = SExpr [Expression]
                | Number Integer
                | Sym String
                | Fn ([Expression] -> Env -> IO (Expression))


--------------------------------------------------------------------
-- Introduce Show

instance Show Expression where
  show (Sym a) = "Symbol : " ++ a
  show (Number a) = "Number : " ++ (show a)
  show (Fn b) = "*FN*"
  show (SExpr (h:t)) = "(" ++
                       show(h) ++
                       (Prelude.foldl (\ start exp -> (start ++ ", " ++ show(exp))) "" t) ++ 
                       ")"



data LispError = SyntaxError
               | InvalidVar
               | InvalidArgs
                 deriving (Show, Typeable)

instance Exception LispError


number :: Parser Expression
number = fmap (Number . read) $ many1 $ oneOf "1234567890"


symbol :: Parser Expression
symbol = fmap Sym $ many1 $ oneOf "+"

program :: Parser [Expression]
program =
  do first <- expression
     next <- remainingExpressions
     return (first : next)

remainingExpressions :: Parser [Expression]
remainingExpressions =
    (oneOf " ,\n" >> program)
    <|> return []


sexp :: Parser Expression
sexp = do
    char '('
    exp <- program
    char ')'
    return $ SExpr exp


expression :: Parser Expression
expression = sexp 
    <|> number
    <|> symbol


parseExpr :: String -> Either ParseError Expression
parseExpr = parse expression "(unknown)"


eval :: Expression -> Env -> IO (Expression)
eval (Number n) env = return $ Number n
eval (SExpr e) env = evalSexpr e env
eval (Sym s) env = lookupEnv s env
eval _ _ = throwIO SyntaxError


evalSexpr :: [Expression] -> Env -> IO (Expression)
evalSexpr (es:t) env = do
   s <- eval es env
   applyFn s t env
evalSexpr _ _ = throwIO SyntaxError


runEval :: Either ParseError Expression -> Env -> IO (Expression)
runEval (Right x) env = eval x env
runEval (Left x) env = throwIO SyntaxError


---------------------------------------------------------------------
-- Introduce Enviroment
 
initEnv :: Env
initEnv = fromList [("+", (Fn lispAdd))]


lookupEnv :: String -> Env -> IO (Expression)
lookupEnv sym env = case (lookup sym env) of
  Just x -> return x
  Nothing -> throwIO InvalidVar 


---------------------------------------------------------------------
-- Introduce Fn Processing
  
lispAdd :: [Expression] -> Env -> IO (Expression)
lispAdd (x:[]) env = eval x env
lispAdd (e:t) env = do
  (Number x) <- eval e env 
  (Number rst) <- lispAdd t env
  return $ Number $ x + rst
lispAdd _ _ = throwIO InvalidArgs


applyFn :: Expression -> [Expression] -> Env -> IO (Expression)
applyFn (Fn f) args env = f args env


main :: IO ()
main = do
  let ast = parseExpr "(+ 1 (+ 2 3 4))"
  putStr $ (show ast) ++ "\n" 
  res <- runEval ast $ initEnv
  putStr $ (show res) ++ "\n"

