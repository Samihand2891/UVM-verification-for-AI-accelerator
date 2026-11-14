from pyuvm import uvm_sequence
from matrix_item import MatrixOperation

class MatrixOperationSequence(uvm_sequence): 
    async def body(self) : 
        operation = MatrixOperation(name = "k3_signed_operation" , k_len =3, 
                                
                    matrix_a= [[1,-2,3] , [4,5,-6] , [-7 , 8 ,9] , [10 , -11 , 12]] ,
                             
                             
                             matrix_b= [[2,-3,4,5] , [-6 , 7 , -8 , 9] , [10 , -11 , 12 , -13]] , 
                                             )




        await self.start_item(operation)
        await self.finish_item(operation) 

