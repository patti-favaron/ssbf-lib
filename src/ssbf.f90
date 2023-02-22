! ssbf - Module, implementing the "simple sonic binary format" data protocol
!
! Copyright 2023 Patrizia Favaron
!
! Permission is hereby granted, free of charge, to any person obtaining a copy
! of this software and associated documentation files (the "Software"), to deal
! in the Software without restriction, including without limitation the rights
! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
! copies of the Software, and to permit persons to whom the Software is furnished
! to do so, subject to the following conditions:
!
! The above copyright notice and this permission notice shall be included
! in all copies or substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
! INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR
! A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
! COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
! IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
! WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
!

module ssbf
    
    use datetime
    
    implicit none
    
    private
    
    ! Public interfaces
    public  :: DailySet
    public  :: ReadAll
    public  :: SSB_FILE_TYPE_METEOFLUX_CORE_V2
    public  :: SSB_FILE_TYPE_METEOFLUX_CORE_V1
    public  :: SSB_FILE_TYPE_WINDRECORDER
    public  :: SSB_FILE_TYPE_SONICLIB
    
    ! Constants (please don't change)
    integer, parameter  :: SSB_FILE_TYPE_METEOFLUX_CORE_V2 = 1
    integer, parameter  :: SSB_FILE_TYPE_METEOFLUX_CORE_V1 = 2
    integer, parameter  :: SSB_FILE_TYPE_WINDRECORDER      = 3
    integer, parameter  :: SSB_FILE_TYPE_SONICLIB          = 4
    
    ! Directory separator (please don't change; also, please specify Fortran preprocessor with --fpp or /fpp)
    character   :: cSep
    
    ! Data types
    
    type HourlySet
        
        ! Data members
        integer                                 :: iNumData
        integer                                 :: iInferredDataRate
        logical                                 :: lGapsInData
        integer(2), dimension(:), allocatable   :: ivTimeStamp
        integer(2), dimension(:), allocatable   :: ivU
        integer(2), dimension(:), allocatable   :: ivV
        integer(2), dimension(:), allocatable   :: ivW
        integer(2), dimension(:), allocatable   :: ivT
        
    contains
    
        procedure, public   :: Init => HourlyInit
        procedure, public   :: Read => HourlyRead
        
    end type HourlySet
    

    type DailySet
        
        private
        
        ! Data members
        integer(2)                          :: iYear
        integer(1)                          :: iMonth
        integer(1)                          :: iDay
        integer(1)                          :: iReserved1
        integer(1)                          :: iReserved2
        integer                             :: iTotalData
        integer, dimension(0:23)            :: ivNumData
        type(HourlySet), dimension(0:23)    :: tvHourlySet
        logical                             :: lComplete = .false.
        
    contains
    
        ! Construct
        procedure, public       :: Init  => DailyInit
        
        ! Read and write
        procedure, public       :: Get   => DailyGet
        procedure, public       :: Read  => DailyRead
        procedure, public       :: Write => DailyWrite
        
        ! Enquiry
        procedure, public       :: isComplete
        procedure, public       :: getTotalData
        procedure, public       :: getNumData
        procedure, public       :: getDataRate
        procedure, public       :: isGap
        
    end type DailySet
    
contains

    ! ***************************************
    ! * Member functions of type 'DailySet' *
    ! ***************************************

    function DailyInit(this) result(iRetCode)
        
        ! Routine arguments
        class(DailySet), intent(out)    :: this
        integer                         :: iRetCode
        
        ! Locals
        integer     :: i
        
        ! Assume success (will falsify on failure)
        iRetCode = 0
        
        ! Assign empty data spaces
        do i = 0, 23
            iRetCode = this % tvHourlySet(i) % Init()
        end do
        this % lComplete = .false.
        
    end function DailyInit


    function DailyGet(this, sDataPath, iYear, iMonth, iDay, iFileType) result(iRetCode)
        
        ! Routine arguments
        class(DailySet), intent(out)    :: this
        character(len=256), intent(in)  :: sDataPath
        integer, intent(in)             :: iYear
        integer, intent(in)             :: iMonth
        integer, intent(in)             :: iDay
        integer, intent(in)             :: iFileType
        integer                         :: iRetCode
        
        ! Locals
        integer             :: iErrCode
        integer             :: iHour
        character(len=256)  :: sFileName
        
        ! Assume success (will falsify on failure)
        iRetCode = 0

        ! OS-dependent initializations
        cSep = '\\'
        ! Please specify cSep = '/' on Linux and Mac OS/X

        ! Pre-assign components
        this % iYear  = int(iYear, kind=2)
        this % iMonth = int(iMonth, kind=1)
        this % iDay   = int(iDay, kind=1)
        this % iReserved1    = 0
        
        ! Main loop: get hourly data
        this % iTotalData = 0
        do iHour = 0, 23
            
            ! Form file name depending on file type
            select case(iFileType)
                
            case(SSB_FILE_TYPE_METEOFLUX_CORE_V1)
                write(sFileName, "(a,a,i4.4,2i2.2,'.',i2.2,'r')") trim(sDataPath), cSep, iYear, iMonth, iDay, iHour
                
            case(SSB_FILE_TYPE_METEOFLUX_CORE_V2)
                write(sFileName, "(a,a,i4.4,i2.2,a,i4.4,2i2.2,'.',i2.2,'R')") &
                    trim(sDataPath), cSep, &
                    iYear, iMonth, cSep, &
                    iYear, iMonth, iDay, iHour
                    
            case(SSB_FILE_TYPE_SONICLIB)
                write(sFileName, "(a,a,i4.4,2i2.2,'.',i2.2,'.csv')") &
                    trim(sDataPath), cSep, &
                    iYear, iMonth, iDay, iHour
                
            case(SSB_FILE_TYPE_WINDRECORDER)
                
            end select
            
            ! Read this hour's data (error code can be safely ignored in this version)
            iErrCode = this % tvHourlySet(iHour) % Read(sFileName, iFileType)
            
            ! Update data count: it should be > 0 on successful completion
            this % ivNumData(iHour) = this % tvHourlySet(iHour) % iNumData
            this % iTotalData = this % iTotalData + this % ivNumData(iHour)
            this % lComplete = .true.
            
        end do
        
        ! Check something has been read
        if(this % iTotalData <= 0) then
            iRetCode = 1
            this % lComplete = .false.
        end if
        
    end function DailyGet
    
    
    function DailyRead(this, sFileName) result(iRetCode)
        
        ! Routine arguments
        class(DailySet), intent(out)    :: this
        character(len=*), intent(in)    :: sFileName
        integer                         :: iRetCode
        
        ! Locals
        integer             :: iLUN
        integer             :: i
        integer             :: iErrCode
        character(len=6)    :: sMagicSequence
        
        ! Assume success (will falsify on failure)
        iRetCode = 0
        
        ! Read data to file
        this % lComplete = .false.
        open(newunit = iLUN, file = sFileName, status = 'old', action = 'read', access = 'stream', iostat=iErrCode)
        if(iErrCode /= 0) then
            iRetCode = 1
            return
        end if
        read(iLUN, iostat=iErrCode) sMagicSequence
        if(iErrCode /= 0 .or. sMagicSequence /= 'ssb_v0') then
            iRetCode = 2
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) this % iReserved1
        if(iErrCode /= 0) then
            iRetCode = 5
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) this % iReserved2
        if(iErrCode /= 0) then
            iRetCode = 5
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) this % iYear
        if(iErrCode /= 0) then
            iRetCode = 6
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) this % iMonth
        if(iErrCode /= 0) then
            iRetCode = 7
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) this % iDay
        if(iErrCode /= 0) then
            iRetCode = 8
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) this % iTotalData
        if(iErrCode /= 0) then
            iRetCode = 9
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) this % ivNumData
        if(iErrCode /= 0) then
            iRetCode = 10
            close(iLUN)
            return
        end if
        do i = 0, 23
            if(allocated(this % tvHourlySet(i) % ivTimeStamp)) deallocate(this % tvHourlySet(i) % ivTimeStamp)
            allocate(this % tvHourlySet(i) % ivTimeStamp(this % ivNumData(i)))
            read(iLUN, iostat=iErrCode) this % tvHourlySet(i) % ivTimeStamp
            if(iErrCode /= 0) then
                iRetCode = 11
                close(iLUN)
                return
            end if
        end do
        do i = 0, 23
            if(allocated(this % tvHourlySet(i) % ivU))         deallocate(this % tvHourlySet(i) % ivU)
            allocate(this % tvHourlySet(i) % ivU(this % ivNumData(i)))
            read(iLUN, iostat=iErrCode) this % tvHourlySet(i) % ivU
            if(iErrCode /= 0) then
                iRetCode = 12
                close(iLUN)
                return
            end if
        end do
        do i = 0, 23
            if(allocated(this % tvHourlySet(i) % ivV))         deallocate(this % tvHourlySet(i) % ivV)
            allocate(this % tvHourlySet(i) % ivV(this % ivNumData(i)))
            read(iLUN, iostat=iErrCode) this % tvHourlySet(i) % ivV
            if(iErrCode /= 0) then
                iRetCode = 13
                close(iLUN)
                return
            end if
        end do
        do i = 0, 23
            if(allocated(this % tvHourlySet(i) % ivW))         deallocate(this % tvHourlySet(i) % ivW)
            allocate(this % tvHourlySet(i) % ivW(this % ivNumData(i)))
            read(iLUN, iostat=iErrCode) this % tvHourlySet(i) % ivW
            if(iErrCode /= 0) then
                iRetCode = 14
                close(iLUN)
                return
            end if
        end do
        do i = 0, 23
            if(allocated(this % tvHourlySet(i) % ivT))         deallocate(this % tvHourlySet(i) % ivT)
            allocate(this % tvHourlySet(i) % ivT(this % ivNumData(i)))
            read(iLUN, iostat=iErrCode) this % tvHourlySet(i) % ivT
            if(iErrCode /= 0) then
                iRetCode = 15
                close(iLUN)
                return
            end if
        end do
        close(iLUN)
        
        ! Leave
        this % lComplete = .true.
        
    end function DailyRead


    function DailyWrite(this, sDataPath, iYear, iMonth, iDay) result(iRetCode)
        
        ! Routine arguments
        class(DailySet), intent(in)     :: this
        character(len=*), intent(in)    :: sDataPath
        integer, intent(in)             :: iYear
        integer, intent(in)             :: iMonth
        integer, intent(in)             :: iDay
        integer                         :: iRetCode
        
        ! Locals
        integer             :: iLUN
        character(len=256)  :: sFileName
        integer             :: i
        
        ! Assume success (will falsify on failure)
        iRetCode = 0
        
        ! Generate SSBF file name from path and date
        write(sFileName, "(a,'/',i4.4,2('-',i2.2),'.ssb')") trim(sDataPath), iYear, iMonth, iDay
        
        ! Write data to file
        if(.not. this % lComplete) then
            iRetCode = 1
            return
        end if
        open(newunit = iLUN, file = sFileName, status = 'unknown', action = 'write', access = 'stream')
        write(iLUN) 'ssb_v0'
        write(iLUN) this % iReserved1
        write(iLUN) this % iReserved2
        write(iLUN) this % iYear
        write(iLUN) this % iMonth
        write(iLUN) this % iDay
        write(iLUN) this % iTotalData
        write(iLUN) this % ivNumData
        do i = 0, 23
            write(iLUN) this % tvHourlySet(i) % ivTimeStamp
        end do
        do i = 0, 23
            write(iLUN) this % tvHourlySet(i) % ivU
        end do
        do i = 0, 23
            write(iLUN) this % tvHourlySet(i) % ivV
        end do
        do i = 0, 23
            write(iLUN) this % tvHourlySet(i) % ivW
        end do
        do i = 0, 23
            write(iLUN) this % tvHourlySet(i) % ivT
        end do
        close(iLUN)
        
    end function DailyWrite
    
    
    function isComplete(this) result(lComplete)
        
        ! Routine arguments
        class(DailySet), intent(in)     :: this
        logical                         :: lComplete
        
        ! Locals
        ! -none-
        
        ! Get the information desired
        lComplete = this % lComplete
            
    end function isComplete


    function getTotalData(this) result(iNumData)
        
        ! Routine arguments
        class(DailySet), intent(in)     :: this
        integer                         :: iNumData
        
        ! Locals
        ! -none-
        
        ! Get the information desired
        iNumData = this % iTotalData
            
    end function getTotalData


    function getNumData(this) result(ivNumData)
        
        ! Routine arguments
        class(DailySet), intent(in)     :: this
        integer, dimension(0:23)        :: ivNumData
        
        ! Locals
        ! -none-
        
        ! Get the information desired
        ivNumData = this % ivNumData
            
    end function getNumData


    function getDataRate(this, ivRate) result(iMinDataRate)
        
        ! Routine arguments
        class(DailySet), intent(in)                     :: this
        integer, dimension(0:23), intent(out), optional :: ivRate
        integer                                         :: iMinDataRate
        
        ! Locals
        integer :: i
        
        ! Get the information desired
        iMinDataRate = huge(iMinDataRate)
        do i = 0, 23
            iMinDataRate = min(iMinDataRate, this % tvHourlySet(i) % iInferredDataRate)
            if(present(ivRate)) ivRate(i) = this % tvHourlySet(i) % iInferredDataRate
        end do
            
    end function getDataRate


    function isGap(this) result(lIsGap)
        
        ! Routine arguments
        class(DailySet), intent(in)     :: this
        logical                         :: lIsGap
        
        ! Locals
        integer :: i
        
        ! Get the information desired
        lIsGap = .false.
        do i = 0, 23
            if(this % tvHourlySet(i) % iNumData > 0) then
                if(this % tvHourlySet(i) % lGapsInData) then
                    lIsGap = .true.
                    exit
                end if
            end if
        end do
            
    end function isGap


    ! ****************************************
    ! * Member functions of type 'HourlySet' *
    ! ****************************************

    function HourlyInit(this) result(iRetCode)
        
        ! Routine arguments
        class(HourlySet), intent(out)   :: this
        integer                         :: iRetCode
        
        ! Locals
        ! --none--
        
        ! Assume success (will falsify on failure)
        iRetCode = 0
        
        ! Assign empty data spaces
        if(allocated(this % ivTimeStamp)) deallocate(this % ivTimeStamp)
        if(allocated(this % ivU))         deallocate(this % ivU)
        if(allocated(this % ivV))         deallocate(this % ivV)
        if(allocated(this % ivW))         deallocate(this % ivW)
        if(allocated(this % ivT))         deallocate(this % ivT)
        
    end function HourlyInit


    function HourlyRead(this, sDataFile, iFileType) result(iRetCode)
        
        ! Routine arguments
        class(HourlySet), intent(out)   :: this
        character(len=256), intent(in)  :: sDataFile
        integer, intent(in)             :: iFileType
        integer                         :: iRetCode
        
        ! Constants
        integer, parameter  :: MAX_DATA = nint(3600*10*4*1.1)   ! 40Hz plus safety limit
        
        ! Locals
        integer                                 :: iErrCode
        integer                                 :: iLUN
        character(len=64)                       :: sBuffer
        character(len=64)                       :: sDataLine
        integer(2), dimension(:), allocatable   :: ivTimeStamp
        integer(2), dimension(:), allocatable   :: ivU
        integer(2), dimension(:), allocatable   :: ivV
        integer(2), dimension(:), allocatable   :: ivW
        integer(2), dimension(:), allocatable   :: ivT
        integer(2), dimension(5)                :: ivData
        integer, dimension(128)                 :: ivNumStampsPerSecond
        integer, dimension(1)                   :: ivPos
        integer                                 :: iCount
        integer                                 :: i
        integer                                 :: iDeltaT
        integer                                 :: iNumLines
        real                                    :: rTimeStamp
        
        ! Assume success (will falsify on failure)
        iRetCode = 0
        
        ! Allocate vectors
        allocate(ivTimeStamp(MAX_DATA))
        allocate(ivU(MAX_DATA))
        allocate(ivV(MAX_DATA))
        allocate(ivW(MAX_DATA))
        allocate(ivT(MAX_DATA))
        
        ! Perform actual reading
        select case(iFileType)
            
        case(SSB_FILE_TYPE_METEOFLUX_CORE_V1)
            
            open(newunit=iLUN, file=sDataFile, status='old', action='read', iostat=iErrCode)
            if(iErrCode /= 0) then
                this % iNumData = 0
                iRetCode = 1
                return
            end if
            iNumLines = 0
            do
                
                ! Get line
                read(iLUN, "(a)", iostat=iErrCode) sBuffer
                if(iErrCode /= 0) exit
                
                ! Read lines to local space
                if(sBuffer(2:2) /= "E" .and. sBuffer(7:12) /= "      ") then
                    iNumLines = iNumLines + 1
                    read(sBuffer, *) sDataLine, rTimeStamp, ivTimeStamp(iNumLines)
                    read(sDataLine, "(1x,4(4x,i6))") &
                        ivV(iNumLines), &
                        ivU(iNumLines), &
                        ivW(iNumLines), &
                        ivT(iNumLines)
                end if
                
            end do
            close(iLUN)
            
            iErrCode = this % Init()
            
            if(iNumLines > 0) then
                
                ! Reserve workspace and fill it
                allocate(this % ivTimeStamp(iNumLines))
                allocate(this % ivU(iNumLines))
                allocate(this % ivV(iNumLines))
                allocate(this % ivW(iNumLines))
                allocate(this % ivT(iNumLines))
                this % ivTimeStamp = ivTimeStamp(1:iNumLines)
                this % ivU         = ivU(1:iNumLines)
                this % ivV         = ivV(1:iNumLines)
                this % ivW         = ivW(1:iNumLines)
                this % ivT         = ivT(1:iNumLines)
                this % iNumData    = iNumLines
                
            else
                
                this % iNumData = 0
                
            end if
            
        case(SSB_FILE_TYPE_METEOFLUX_CORE_V2)
            
            open(newunit=iLUN, file=sDataFile, status='old', action='read', access='stream', iostat=iErrCode)
            if(iErrCode /= 0) then
                this % iNumData = 0
                iRetCode = 1
                return
            end if
            iNumLines = 0
            do
                
                ! Get line
                read(iLUN, iostat=iErrCode) ivData
                if(iErrCode /= 0) exit
                
                ! Read lines to local space
                if(ivData(1) < 5000 .and. ivData(2) > -9000) then
                    iNumLines = iNumLines + 1
                    if(iNumLines > MAX_DATA) exit
                    ivTimeStamp(iNumLines)  = ivData(1)
                    ivV(iNumLines)          = ivData(3)
                    ivU(iNumLines)          = ivData(2)
                    ivW(iNumLines)          = ivData(4)
                    ivT(iNumLines)          = ivData(5)
                end if
                
            end do
            close(iLUN)
            
            iErrCode = this % Init()
            
            if(iNumLines > 0) then
                
                ! Reserve workspace and fill it
                allocate(this % ivTimeStamp(iNumLines))
                allocate(this % ivU(iNumLines))
                allocate(this % ivV(iNumLines))
                allocate(this % ivW(iNumLines))
                allocate(this % ivT(iNumLines))
                this % ivTimeStamp = ivTimeStamp(1:iNumLines)
                this % ivU         = ivU(1:iNumLines)
                this % ivV         = ivV(1:iNumLines)
                this % ivW         = ivW(1:iNumLines)
                this % ivT         = ivT(1:iNumLines)
                this % iNumData    = iNumLines
                
            else
                
                this % iNumData = 0
                
            end if
            
        end select
        
        ! Estimate data rate
        iCount               = 0
        ivNumStampsPerSecond = 0
        do i = 1, size(this % ivTimeStamp) - 1
            if(this % ivTimeStamp(i+1) /= this % ivTimeStamp(i)) then
                iCount = iCount + 1
                if(iCount <= size(ivNumStampsPerSecond)) then
                    ivNumStampsPerSecond(iCount) = ivNumStampsPerSecond(iCount) + 1
                end if
                iCount = 0
            else
                iCount = iCount + 1
            end if
        end do
        ivPos = maxloc(ivNumStampsPerSecond)
        this % iInferredDataRate = ivPos(1)
        
        ! Check some gap exists
        this % lGapsInData = .false.
        do i = 1, size(this % ivTimeStamp) - 1
            iDeltaT = this % ivTimeStamp(i+1) - this % ivTimeStamp(i)
            if(iDeltaT /= 0 .and. iDeltaT /= 1) then
                this % lGapsInData = .true.
                exit
            end if
        end do
        
        ! Leave
        deallocate(ivT)
        deallocate(ivW)
        deallocate(ivV)
        deallocate(ivU)
        deallocate(ivTimeStamp)
        
    end function HourlyRead


    ! *****************************
    ! * Read full SSB format file *
    ! *****************************
    
    function ReadAll(sFileName, ivTimeStamp, ivU, ivV, ivW, ivT, ivNumData, ivDataRate) result(iRetCode)
        
        ! Routine arguments
        character(len=*), intent(in)                        :: sFileName
        integer, dimension(:), allocatable, intent(out)     :: ivTimeStamp
        integer(2), dimension(:), allocatable, intent(out)  :: ivU
        integer(2), dimension(:), allocatable, intent(out)  :: ivV
        integer(2), dimension(:), allocatable, intent(out)  :: ivW
        integer(2), dimension(:), allocatable, intent(out)  :: ivT
        integer, dimension(0:23), intent(out)               :: ivNumData
        integer, dimension(0:23), intent(out)               :: ivDataRate
        integer                                             :: iRetCode
        
        ! Locals
        integer                                 :: iErrCode
        integer                                 :: iLUN
        character(len=6)                        :: sMagicSequence
        integer(2)                              :: iYear
        integer(1)                              :: iMonth
        integer(1)                              :: iDay
        integer(1)                              :: iHour
        integer(1)                              :: iReserved1
        integer(1)                              :: iReserved2
        integer                                 :: iTotalData
        integer                                 :: iCurData
        integer                                 :: i
        integer                                 :: iBegin
        integer                                 :: iBaseTime
        integer(2), dimension(:), allocatable   :: ivSecondStamp
        integer, dimension(128)                 :: ivNumStampsPerSecond
        integer, dimension(1)                   :: ivPos
        integer                                 :: iCount
        
        ! Assume success (will falsify on failure)
        iRetCode = 0
        
        ! Open the file and check it's the right type
        open(newunit=iLUN, file=sFileName, status='old', action='read', access='stream', iostat=iErrCode)
        if(iErrCode /= 0) then
            iRetCode = 1
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) sMagicSequence
        if(iErrCode /= 0 .or. sMagicSequence /= 'ssb_v0') then
            iRetCode = 2
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) iReserved1, iReserved2
        if(iErrCode /= 0) then
            iRetCode = 8
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) iYear, iMonth, iDay
        if(iErrCode /= 0) then
            iRetCode = 9
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) iTotalData
        if(iErrCode /= 0) then
            iRetCode = 10
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) ivNumData
        if(iErrCode /= 0) then
            iRetCode = 11
            close(iLUN)
            return
        end if
        if(allocated(ivTimeStamp))   deallocate(ivTimeStamp)
        if(allocated(ivSecondStamp)) deallocate(ivSecondStamp)
        if(allocated(ivU))           deallocate(ivU)
        if(allocated(ivV))           deallocate(ivV)
        if(allocated(ivW))           deallocate(ivW)
        if(allocated(ivT))           deallocate(ivT)
        allocate(ivTimeStamp(iTotalData))
        allocate(ivSecondStamp(iTotalData))
        allocate(ivU(iTotalData))
        allocate(ivV(iTotalData))
        allocate(ivW(iTotalData))
        allocate(ivT(iTotalData))
        read(iLUN, iostat=iErrCode) ivSecondStamp
        if(iErrCode /= 0) then
            iRetCode = 12
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) ivU
        if(iErrCode /= 0) then
            iRetCode = 13
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) ivV
        if(iErrCode /= 0) then
            iRetCode = 14
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) ivW
        if(iErrCode /= 0) then
            iRetCode = 15
            close(iLUN)
            return
        end if
        read(iLUN, iostat=iErrCode) ivT
        if(iErrCode /= 0) then
            iRetCode = 16
            close(iLUN)
            return
        end if
        close(iLUN)
        
        ! Generate full-scale time stamp
        iCurData = 0
        iBaseTime = toEpoch(Time(iYear, iMonth, iDay, 0_1, 0_1, 0_1))
        do iHour = 0, 23
            ivTimeStamp((iCurData + 1):(iCurData + ivNumData(iHour))) = &
                iBaseTime + iHour*3600 + ivSecondStamp((iCurData + 1):(iCurData + ivNumData(iHour)))
            iCurData = iCurData + ivNumData(iHour)
        end do
        
        ! Estimate data rate
        iBegin = 1
        do iHour = 0, 23
            iCount               = 0
            ivNumStampsPerSecond = 0
            do i = iBegin, iBegin + ivNumData(iHour) - 2
                if(ivSecondStamp(i+1) /= ivSecondStamp(i)) then
                    iCount = iCount + 1
                    if(iCount <= size(ivNumStampsPerSecond)) &
                        ivNumStampsPerSecond(iCount) = ivNumStampsPerSecond(iCount) + 1
                    iCount = 0
                else
                    iCount = iCount + 1
                end if
            end do
            ivPos             = maxloc(ivNumStampsPerSecond)
            ivDataRate(iHour) = ivPos(1)
            iBegin            = iBegin + ivNumData(iHour)
        end do
        
    end function ReadAll

end module ssbf

