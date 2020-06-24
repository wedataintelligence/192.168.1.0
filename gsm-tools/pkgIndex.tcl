# -*- tcl -*-
# $Id: pkgIndex.tcl,v 1.2 2002/10/17 16:48:40 grigory Exp $

# Copyright (c) 2002 Grigory Milev <week@altlinux.ru>
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package ifneeded smslib         0.2 [list source [file join $dir smslib.tcl]]
package ifneeded phonebooklib   0.1 [list source [file join $dir phonebooklib.tcl]]
